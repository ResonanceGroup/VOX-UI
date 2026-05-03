class BleDevice {
  String deviceName;
  String serviceUUID;
  String txCharacteristicUUID;
  String rxCharacteristicUUID;

  BleDevice({
    required this.deviceName,
    required this.serviceUUID,
    required this.txCharacteristicUUID,
    required this.rxCharacteristicUUID,
  });
}