import test from 'node:test';
import assert from 'node:assert/strict';
import { NotificationStore } from '../src/notifications.js';

test('creates one outbox item per enabled device and notice', () => {
  const notifications = new NotificationStore();
  notifications.registerDevice({ deviceId: 'device-1', fcmToken: 'token-1', platform: 'android' });
  notifications.registerDevice({ deviceId: 'device-2', fcmToken: 'token-2', platform: 'android' });
  notifications.setPreference('device-1', 'MN2000194', true);
  notifications.setPreference('device-2', 'MN2000194', false);

  assert.equal(notifications.enqueue({ id: 'notice-1', boardCode: 'MN2000194' }), 1);
  assert.equal(notifications.enqueue({ id: 'notice-1', boardCode: 'MN2000194' }), 0);
  assert.deepEqual(notifications.outbox(), [{ noticeId: 'notice-1', deviceId: 'device-1', status: 'pending' }]);
});
