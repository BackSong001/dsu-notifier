export function classifyFcmError(status: number, body: { error?: { details?: { '@type'?: string; errorCode?: string }[] } }) {
  const detail = body?.error?.details?.find(item => item['@type'] === 'type.googleapis.com/google.firebase.fcm.v1.FcmError');
  const code = detail?.errorCode ?? `FCM_HTTP_${status}`;
  return { code, invalidToken: code === 'UNREGISTERED', retry: status === 429 || status >= 500 };
}
