import 'dart:ui';
import 'package:cargorun_rider/services/auth_service/auth_impl.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'dart:developer';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:developer' as dev;


@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  String? orderId;
  String? userId;
  String? orderStatus;

  final socket = io.io(baseUrlSocket, {
    'transports': ['websocket'],
    'autoConnect': false,
    'forceNew': true,
  });

  // 🔹 Listen for foreground/background events
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setForegroundNotificationInfo(
        title: "Rider Location Service",
        content: "Tracking your live location...",
      );
    });

    service.on('setAsBackground').listen((event) {
      // Handle background downgrade if needed
    });
  }

  // 🔹 Listen for custom IDs from main isolate
  service.on("setIds").listen((event) {
    orderId = event?["orderId"];
    userId = event?["userId"];
    orderStatus = event?["orderStatus"];

    if (orderId != null && userId != null) {
      if (!socket.connected) {
        socket.connect();
      }
    }
  });

  // 🔹 Socket handling
  socket.onConnect((_) => dev.log("✅ Socket connected in background isolate"));
  socket.onDisconnect((_) => dev.log("⚠️ Socket disconnected"));

  // 🔹 Location updates
  const locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5,
  );

  Geolocator.getPositionStream(locationSettings: locationSettings).listen(
    (Position position) {
      dev.log("📍 Background Location: ${position.latitude}, ${position.longitude}");

      if (orderId != null &&
          userId != null &&
          socket.connected &&
          ["accepted", "picked", "arrived"].contains(orderStatus?.toLowerCase())) {
        socket.emit("rider-location", {
          "lat": position.latitude,
          "lng": position.longitude,
          "orderId": orderId,
          "userId": userId,
        });

        dev.log("✅ Location sent via socket: ${position.latitude}, ${position.longitude}");
      }
    },
  );
}

