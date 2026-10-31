import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  /// Opens a chat directly for the given number using a wa.me link.
  static Future<bool> openChat(String waFormattedNumber, {String message = ''}) async {
    final uri = Uri.parse(
      'https://wa.me/$waFormattedNumber${message.isNotEmpty ? '?text=${Uri.encodeComponent(message)}' : ''}',
    );
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}