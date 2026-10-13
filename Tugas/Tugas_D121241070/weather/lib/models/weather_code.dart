/// Terjemahan kode cuaca WMO (dipakai Open-Meteo) ke bahasa Indonesia.
String describeWeatherCode(int code) {
  switch (code) {
    case 0:
      return 'Cerah';
    case 1:
      return 'Cerah berawan';
    case 2:
      return 'Berawan sebagian';
    case 3:
      return 'Mendung';
    case 45:
    case 48:
      return 'Berkabut';
    case 51:
    case 53:
    case 55:
      return 'Gerimis';
    case 56:
    case 57:
      return 'Gerimis beku';
    case 61:
      return 'Hujan ringan';
    case 63:
      return 'Hujan sedang';
    case 65:
      return 'Hujan lebat';
    case 66:
    case 67:
      return 'Hujan beku';
    case 71:
    case 73:
    case 75:
    case 77:
      return 'Salju';
    case 80:
      return 'Hujan lokal ringan';
    case 81:
      return 'Hujan lokal sedang';
    case 82:
      return 'Hujan lokal lebat';
    case 85:
    case 86:
      return 'Hujan salju';
    case 95:
      return 'Badai petir';
    case 96:
    case 99:
      return 'Badai petir dan es';
    default:
      return 'Tidak diketahui';
  }
}
