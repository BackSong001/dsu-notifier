export class NotificationStore {
  #devices = new Map();
  #preferences = new Map();
  #outbox = new Map();

  registerDevice(device) {
    this.#devices.set(device.deviceId, { ...device, active: true });
  }

  setPreference(deviceId, boardCode, enabled) {
    this.#preferences.set(`${deviceId}:${boardCode}`, enabled);
  }

  enqueue(notice) {
    let created = 0;
    for (const [deviceId, device] of this.#devices) {
      if (!device.active || this.#preferences.get(`${deviceId}:${notice.boardCode}`) !== true) continue;
      const key = `${notice.id}:${deviceId}`;
      if (this.#outbox.has(key)) continue;
      this.#outbox.set(key, { noticeId: notice.id, deviceId, status: 'pending' });
      created += 1;
    }
    return created;
  }

  outbox() {
    return [...this.#outbox.values()];
  }
}
