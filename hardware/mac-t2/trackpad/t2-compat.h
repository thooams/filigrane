/* Définitions de la série Asahi (include/linux/hid.h) absentes du noyau Void:
 * périphériques SPI des Mac Apple Silicon, jamais présents sur une T2. */
#define HID_TYPE_SPI_KEYBOARD 100
#define HID_TYPE_SPI_MOUSE 101
#define HID_SPI_DEVICE(ven, prod) .bus = BUS_SPI, .vendor = (ven), .product = (prod)
