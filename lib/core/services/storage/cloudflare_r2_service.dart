import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:vens_hub/core/config/app_config.dart';
import 'package:vens_hub/core/error/exceptions.dart';
import 'package:vens_hub/core/di/injection_container.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CloudflareR2Service {
  FirebasePerformance? get _performance =>
      sl.isRegistered<FirebasePerformance>() ? sl<FirebasePerformance>() : null;

  CloudflareR2Service();

  Future<List<Map<String, String>>> getDocumentsFromPath(String path) async {
    final trace =
        kIsWeb
            ? null
            : _performance?.newTrace('cloudflare_r2_getDocumentsFromPath');
    trace?.putAttribute('path', path);
    await trace?.start();

    List<Map<String, String>> data = [];

    try {
      // For Cloudflare R2, we'll need to list objects from a specific path
      // Since R2 doesn't have a direct list API like Firebase, we'll use a predefined list
      // or fetch from a metadata endpoint if available

      // For now, let's create a mock implementation that returns textbooks from Cloudflare
      // You can replace this with actual R2 listing logic when available

      final textbooks = await _getTextbooksFromCloudflare(path);

      for (var textbook in textbooks) {
        data.add({"name": textbook['name'], "url": textbook['url']});
        log("Got Document ${textbook['name']}: ${textbook['url']}");
      }

      trace?.setMetric('items_found', data.length);
      return data;
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      log("Cloudflare R2 Error: $e");
      throw StorageException(message: "Cloudflare R2 Error: $e");
    } finally {
      await trace?.stop();
    }
  }

  Future<List<Map<String, dynamic>>> _getTextbooksFromCloudflare(
    String path,
  ) async {
    // This is a mock implementation - replace with actual R2 listing logic
    // For now, we'll return some sample textbooks that would be stored in Cloudflare R2

    final baseUrl = AppConfig.r2PublicDomain;

    // Sample textbooks - replace with actual data from your R2 bucket
    final textbooks = [
      {
        'name': 'Data Communication and Networking',
        'url': '$baseUrl/textbooks/data-communication-networking.pdf',
        'path': 'textbooks/data-communication-networking.pdf',
      },
      {
        'name': 'Computer Networks Fundamentals',
        'url': '$baseUrl/textbooks/computer-networks-fundamentals.pdf',
        'path': 'textbooks/computer-networks-fundamentals.pdf',
      },
      {
        'name': 'Digital Signal Processing',
        'url': '$baseUrl/textbooks/digital-signal-processing.pdf',
        'path': 'textbooks/digital-signal-processing.pdf',
      },
      {
        'name': 'Communication Systems',
        'url': '$baseUrl/textbooks/communication-systems.pdf',
        'path': 'textbooks/communication-systems.pdf',
      },
      {
        'name': 'Network Security Principles',
        'url': '$baseUrl/textbooks/network-security-principles.pdf',
        'path': 'textbooks/network-security-principles.pdf',
      },
      {
        'name': 'Wireless Communications',
        'url': '$baseUrl/textbooks/wireless-communications.pdf',
        'path': 'textbooks/wireless-communications.pdf',
      },
      {
        'name': 'Optical Fiber Communications',
        'url': '$baseUrl/textbooks/optical-fiber-communications.pdf',
        'path': 'textbooks/optical-fiber-communications.pdf',
      },
      {
        'name': 'Satellite Communications',
        'url': '$baseUrl/textbooks/satellite-communications.pdf',
        'path': 'textbooks/satellite-communications.pdf',
      },
    ];

    // Filter textbooks based on the path if needed
    if (path.contains('Data Communication') || path.contains('elect')) {
      return textbooks
          .where(
            (book) =>
                (book['name'])?.toLowerCase().contains('communication') ==
                    true ||
                (book['name'])?.toLowerCase().contains('network') == true,
          )
          .toList();
    }

    return textbooks;
  }

  // Method to verify if a file exists in R2
  Future<bool> fileExists(String filePath) async {
    try {
      final url = '$baseUrl/$filePath';
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      log("Error checking file existence: $e");
      return false;
    }
  }

  String get baseUrl => AppConfig.r2PublicDomain;
}
