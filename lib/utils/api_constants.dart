class ApiConstants {
  // FLIP THIS TO TRUE WHEN DEPLOYING TO BETTERGYM.ONLINE
  static const bool kIsProduction = false; 

  // --- LOCAL XAMPP TESTING ---
  static const String baseUrl = "http://192.168.100.14/bettergym_api"; 

// EXISTING ENDPOINTS
  static const String syncSessionEndpoint = "$baseUrl/sync_session.php";
  static const String fetchHistoryEndpoint = "$baseUrl/fetch_history.php";
  
  // THE NEW ENDPOINT
  static const String updateSettingsEndpoint = "$baseUrl/update_settings.php";
}