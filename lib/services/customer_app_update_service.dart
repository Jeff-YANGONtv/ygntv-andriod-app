import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

const customerReleaseManifestUrl =
    'https://ygntv.org/app-updates/customer-stable/latest.json';
const _packageName = 'org.ygntv.ygntv_customer';
const _updateChannel = MethodChannel('org.ygntv.customer/app_update');

class AppUpdateRelease {
  const AppUpdateRelease({
    required this.channel,
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.sha256,
    required this.releaseNotes,
    this.sizeBytes = 0,
  });

  final String channel;
  final String packageName;
  final String versionName;
  final int versionCode;
  final Uri apkUrl;
  final String sha256;
  final String releaseNotes;
  final int sizeBytes;

  factory AppUpdateRelease.fromJson(Map<String, dynamic> json) {
    final channel = json['channel'];
    final packageName = json['package_name'];
    final versionName = json['version_name'];
    final versionCode = json['version_code'];
    final apkUrl = Uri.tryParse('${json['apk_url'] ?? ''}');
    final sha256 = '${json['sha256'] ?? ''}'.toLowerCase();
    if (channel != 'customer-stable' ||
        packageName != _packageName ||
        versionName is! String ||
        versionName.trim().isEmpty ||
        versionCode is! num ||
        versionCode <= 0 ||
        apkUrl == null ||
        apkUrl.scheme != 'https' ||
        !{'ygntv.org', 'www.ygntv.org'}.contains(apkUrl.host.toLowerCase()) ||
        !RegExp(r'^/app-updates/customer-stable/[A-Za-z0-9._-]+\.apk$')
            .hasMatch(apkUrl.path) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256)) {
      throw const FormatException('The YGNTV update manifest is invalid.');
    }
    return AppUpdateRelease(
      channel: channel as String,
      packageName: packageName as String,
      versionName: versionName,
      versionCode: versionCode.toInt(),
      apkUrl: apkUrl,
      sha256: sha256,
      releaseNotes: json['release_notes'] is String
          ? json['release_notes'] as String
          : '',
      sizeBytes: json['size_bytes'] is num
          ? (json['size_bytes'] as num).toInt()
          : 0,
    );
  }
}

class AppUpdateDownloadStatus {
  const AppUpdateDownloadStatus({
    required this.status,
    this.progress,
    this.checksumValid,
    this.message,
  });

  final String status;
  final double? progress;
  final bool? checksumValid;
  final String? message;

  bool get isFinished => status == 'complete' || status == 'failed';

  factory AppUpdateDownloadStatus.fromMap(Map<Object?, Object?> value) {
    final downloaded = (value['bytes_downloaded'] as num?)?.toDouble() ?? 0;
    final total = (value['total_bytes'] as num?)?.toDouble() ?? 0;
    return AppUpdateDownloadStatus(
      status: '${value['status'] ?? 'unknown'}',
      progress: total > 0 ? (downloaded / total).clamp(0, 1) : null,
      checksumValid: value['checksum_valid'] as bool?,
      message: value['message'] as String?,
    );
  }
}

class CustomerAppUpdateService {
  CustomerAppUpdateService({http.Client? client, MethodChannel? channel})
    : _client = client ?? http.Client(),
      _channel = channel ?? _updateChannel;

  final http.Client _client;
  final MethodChannel _channel;

  Future<AppUpdateRelease> fetchLatestRelease() async {
    final response = await _client.get(
      Uri.parse(customerReleaseManifestUrl),
      headers: const {'Accept': 'application/json'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const FormatException('The latest YGNTV app could not be checked.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('The YGNTV update manifest is invalid.');
    }
    return AppUpdateRelease.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<AppUpdateRelease?> findAvailableUpdate({
    int? installedVersionCode,
  }) async {
    final current =
        installedVersionCode ??
        int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ??
        0;
    final latest = await fetchLatestRelease();
    if (latest.versionCode <= current) return null;
    return latest;
  }

  Future<int> startApkDownload(AppUpdateRelease release) async {
    final id = await _channel.invokeMethod<int>('startDownload', {
      'url': release.apkUrl.toString(),
      'sha256': release.sha256,
      'fileName': release.apkUrl.pathSegments.last,
      'title': 'YGNTV ${release.versionName} update',
    });
    if (id == null || id <= 0) {
      throw const FormatException(
        'The YGNTV update download could not be started.',
      );
    }
    return id;
  }

  Future<AppUpdateDownloadStatus> downloadStatus(int id) async {
    final value = await _channel.invokeMethod<Map<Object?, Object?>>(
      'downloadStatus',
      {'id': id},
    );
    if (value == null) {
      throw const FormatException(
        'The YGNTV update download could not be found.',
      );
    }
    return AppUpdateDownloadStatus.fromMap(value);
  }

  Future<bool> canInstallPackages() async =>
      await _channel.invokeMethod<bool>('canInstallPackages') ?? false;

  Future<void> openInstallPermissionSettings() =>
      _channel.invokeMethod<void>('openInstallPermissionSettings');

  Future<void> installDownloadedApk(int id) =>
      _channel.invokeMethod<void>('installDownloadedApk', {'id': id});
}
