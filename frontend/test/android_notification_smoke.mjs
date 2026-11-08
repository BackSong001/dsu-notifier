// dsu_nofiter의 설치 앱과 현재 Chrome 탭을 사용하는 Android 통합 검사다.
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const run = (...args) => execFileSync('adb', args, {encoding: 'utf8'}).trim();
const serials = run('devices').split('\n').slice(1).filter(line => line.includes('\tdevice')).map(line => line.split(/\s+/)[0]);
const devices = serials.filter(serial => run('-s', serial, 'emu', 'avd', 'name').split('\n')[0].trim() === 'dsu_nofiter');
assert.equal(devices.length, 1, 'Exactly one dsu_nofiter AVD must be connected');
const serial = devices[0];
const adb = (...args) => {
  assert.equal(run('-s', serial, 'emu', 'avd', 'name').split('\n')[0].trim(), 'dsu_nofiter');
  return run('-s', serial, ...args);
};
const port = adb('forward', 'tcp:0', 'localabstract:chrome_devtools_remote');

async function visibleUrl() {
  const pages = await (await fetch(`http://127.0.0.1:${port}/json/list`, {signal: AbortSignal.timeout(5000)})).json();
  const values = await Promise.all(pages.filter(page => page.type === 'page').map(page => new Promise((resolve, reject) => {
    const socket = new WebSocket(page.webSocketDebuggerUrl);
    const timer = setTimeout(() => { socket.close(); reject(new Error('Chrome inspection timed out')); }, 5000);
    const finish = (error, value) => { clearTimeout(timer); socket.close(); error ? reject(error) : resolve(value); };
    socket.onopen = () => socket.send(JSON.stringify({id: 1, method: 'Runtime.evaluate', params: {
      expression: 'JSON.stringify({url:location.href,visibility:document.visibilityState})', returnByValue: true,
    }}));
    socket.onerror = () => finish(new Error('Chrome debugging is unavailable'));
    socket.onmessage = ({data}) => {
      const message = JSON.parse(data);
      if (message.id === 1) finish(null, JSON.parse(message.result.result.value));
    };
  })));
  return values.find(page => page.visibility === 'visible')?.url;
}

async function expectUrl(expected) {
  assert.ok(typeof expected === 'string' && expected.length > 0, 'An expected URL is required');
  let actual;
  for (let attempt = 0; attempt < 10; attempt++) {
    actual = await visibleUrl();
    if (actual === expected) return;
    await new Promise(resolve => setTimeout(resolve, 200));
  }
  assert.equal(actual, expected, 'Current visible browser URL must match this notification');
}

const cold = 'https://www.dongseo.ac.kr/kr/index.php?pCode=MN2000194&mode=view&idx=103523';
const warm = 'https://www.dongseo.ac.kr/kr/index.php?pCode=MN2000194&mode=view&idx=103510';
const launch = (url, id) => adb('shell', 'am', 'start', '-W', '-n', 'com.dsu.notifier/.MainActivity', '--es', 'url', `'${url}'`, '--es', 'google.message_id', id);
try {
  if (process.argv[2] === '--expect-url') {
    await expectUrl(process.argv[3]);
    console.log('PASS: current visible Chrome URL matches the actual notification');
  } else {
    adb('shell', 'am', 'force-stop', 'com.dsu.notifier');
    launch(cold, 'smoke-cold');
    await expectUrl(cold);
    adb('shell', 'am', 'start', '-W', '-n', 'com.dsu.notifier/.MainActivity');
    launch(warm, 'smoke-warm');
    await expectUrl(warm);
    launch('https://example.invalid/', 'smoke-untrusted');
    const resumed = adb('shell', 'dumpsys', 'activity', 'activities').split('\n').filter(line => line.includes('topResumedActivity='));
    assert.ok(resumed.some(line => line.includes('com.dsu.notifier/.MainActivity')), 'Untrusted URL must leave the app in front');
    console.log('PASS: distinct cold/warm notification URLs and untrusted-host rejection on dsu_nofiter');
  }
} finally {
  adb('forward', '--remove', `tcp:${port}`);
}
