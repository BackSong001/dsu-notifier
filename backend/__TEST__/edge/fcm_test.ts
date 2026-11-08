import { classifyFcmError } from '../../../supabase/functions/_shared/fcm.ts';
Deno.test('only UNREGISTERED deactivates a device; transient rejection retries', () => {
  for (const status of [401,404]) {
    if (classifyFcmError(status, {}).invalidToken) throw new Error('Disabled a valid device');
  }
  const invalid = {error: {details: [{'@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', errorCode: 'UNREGISTERED'}]}};
  if (!classifyFcmError(404, invalid).invalidToken) throw new Error('Kept an expired token');
  for (const status of [429,500,503]) if (!classifyFcmError(status, {}).retry) throw new Error('Not retrying rejection');
});
