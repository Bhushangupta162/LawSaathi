import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:LawSaathi/app_secrets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CallDetails {
  final String callId;
  final double callLength;
  final String phoneNumber;
  final String createdAt;
  final String summary;
  final String status;

  CallDetails({
    required this.callId,
    required this.callLength,
    required this.phoneNumber,
    required this.createdAt,
    required this.summary,
    required this.status,
  });

  factory CallDetails.fromJson(Map<String, dynamic> json) {
    double callLength = 0.0;
    if (json['call_length'] != null) {
      if (json['call_length'] is num) {
        callLength = (json['call_length'] as num).toDouble();
      } else if (json['call_length'] is String) {
        try {
          callLength = double.parse(json['call_length'] as String);
        } catch (e) {
          // Ignore parse error and keep default
        }
      }
    }

    // Get createdAt from json. If it's missing, get it from the alternate key
    // If both are missing, use an existing valid ISO date instead of now()
    String createdAt =
        json['created_at'] ?? json['createdAt'] ?? '2023-01-01T00:00:00.000Z';

    // Validate ISO date format - if invalid use a valid default date
    try {
      DateTime.parse(createdAt);
    } catch (e) {
      // If we can't parse it, use a default date instead of current time
      // createdAt = '2023-01-01T00:00:00.000Z';
    }

    return CallDetails(
      callId: json['call_id'] ?? '',
      callLength: callLength,
      phoneNumber: json['to'] ?? json['phoneNumber'] ?? '',
      createdAt: createdAt,
      summary: json['summary'] ?? 'No summary available',
      status: json['status'] ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'call_id': callId,
      'call_length': callLength,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt,
      'summary': summary,
      'status': status,
    };
  }
}

class ApiHelper {
  static const String queryBaseUrl = AppSecrets.queryBaseUrl;
  static const String callBaseUrl = AppSecrets.callBaseUrl;
  static const String apiKey = AppSecrets.apiKey;
  static const String callDetailsBaseUrl = 'https://api.bland.ai/v1/calls/';

  // Key for storing call history in SharedPreferences
  static const String callHistoryKey = 'call_history';

  static Future<String> sendQuery(String query) async {
    developer.log('Sending query request to: $queryBaseUrl');
    developer.log('Query payload: ${jsonEncode({"query": query})}');
    try {
      final response = await http.post(
        Uri.parse(queryBaseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"query": query}),
      );
      developer.log('Query response status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        developer.log('Query request successful');
        var data = jsonDecode(response.body);
        developer.log('Response data: $data');
        return data['result'] ?? "No result found";
      } else {
        developer
            .log('Query request failed with status: ${response.statusCode}');
        developer.log('Error response: ${response.body}');
        throw Exception(
            'Failed to load data with status code: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Exception during query request: $e');
      rethrow;
    }
  }

  static Future<String?> makePhoneCall(String phoneNumber) async {
    developer.log('Initiating phone call to: $phoneNumber');
    final payload = {
      "phone_number": phoneNumber,
      "task":
          "The main objective of this phone call is to gather information about the caller's query who is in legal trouble and seeks advice. The goal is to assist the caller's query and give him helpful legal advice pertaining to indian penal code or bharatiya nyaya sanhita.",
      "first_sentence":
          "Hello, I'm calling from LawSaathi, your legal assistant. Could you please tell me about your query?",
      "wait_for_greeting": true,
      "model": "enhanced",
      "tools": [],
      "voice": "Alexa",
      "record": true,
      "voice_settings": {},
      "language": "eng",
      "answered_by_enabled": true,
      "temperature": 0,
      "amd": false,
    };
    developer.log('Call payload: ${json.encode(payload)}');
    final headers = {
      "authorization": apiKey,
      "Content-Type": "application/json",
    };
    try {
      developer.log('Sending call request to: $callBaseUrl');
      final response = await http.post(
        Uri.parse(callBaseUrl),
        headers: headers,
        body: json.encode(payload),
      );
      developer.log('Call response status code: ${response.statusCode}');
      final responseJson = json.decode(response.body);
      if (response.statusCode == 200) {
        developer.log('Call successfully initiated');
        developer.log('Call response: $responseJson');
        developer.log('Call initiated: ${responseJson['message']}');

        // Extract and return the call ID
        String? callId = responseJson['call_id'];
        if (callId != null) {
          // Save the initial call information with status as "initiated"
          await _saveCallToHistory(CallDetails(
            callId: callId,
            callLength: 0.0,
            phoneNumber: phoneNumber,
            createdAt: DateTime.now().toIso8601String(),
            summary: 'Call initiated',
            status: 'initiated',
          ));
        }
        return callId;
      } else {
        developer
            .log('Call request failed with status: ${response.statusCode}');
        developer.log('Error response: $responseJson');
        developer.log(
            'Failed to make call with status code: ${response.statusCode} and message: ${responseJson['message']}');
        return null;
      }
    } catch (e) {
      developer.log('Exception during call request: $e');
      developer.log('Error making call: $e');
      return null;
    }
  }

// In ApiHelper class
  static Future<CallDetails?> getCallDetails(String callId) async {
    developer.log('Fetching call details for call ID: $callId');
    final headers = {
      "authorization": apiKey,
      "Content-Type": "application/json",
    };

    try {
      // First, get the existing call details to preserve creation time
      List<CallDetails> callHistory = await getCallHistory();
      CallDetails? existingCall = callHistory.firstWhere(
        (call) => call.callId == callId,
        orElse: () => CallDetails(
          callId: callId,
          callLength: 0.0,
          phoneNumber: '',
          createdAt: '', // Empty string if not found
          summary: 'No summary available',
          status: 'unknown',
        ),
      );

      final response = await http.get(
        Uri.parse('$callDetailsBaseUrl$callId'),
        headers: headers,
      );

      developer
          .log('Call details response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseJson = json.decode(response.body);
        developer.log('Call details retrieved successfully');
        developer.log('Call details: $responseJson');

        // Create a new call details object from the API response
        CallDetails newCallDetails = CallDetails.fromJson(responseJson);

        // Preserve the original creation time if the API didn't return one
        if (newCallDetails.createdAt.isEmpty &&
            existingCall.createdAt.isNotEmpty) {
          newCallDetails = CallDetails(
            callId: newCallDetails.callId,
            callLength: newCallDetails.callLength,
            phoneNumber: newCallDetails.phoneNumber,
            createdAt: existingCall.createdAt, // Use the original createdAt
            summary: newCallDetails.summary,
            status: newCallDetails.status,
          );
        }

        // Update the call history with the latest details
        await _saveCallToHistory(newCallDetails);
        return newCallDetails;
      } else {
        developer.log(
            'Failed to get call details with status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      developer.log('Exception during call details request: $e');
      return null;
    }
  }

  // Method to save call to history
  static Future<void> _saveCallToHistory(CallDetails callDetails) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing call history
      List<String> callHistoryJson = prefs.getStringList(callHistoryKey) ?? [];
      List<CallDetails> callHistory = callHistoryJson
          .map((json) => CallDetails.fromJson(jsonDecode(json)))
          .toList();

      // Check if this call already exists in the history
      int existingIndex =
          callHistory.indexWhere((call) => call.callId == callDetails.callId);

      if (existingIndex != -1) {
        // Update existing call
        callHistory[existingIndex] = callDetails;
      } else {
        // Add new call to history
        callHistory.add(callDetails);
      }

      // Save updated call history
      callHistoryJson =
          callHistory.map((call) => jsonEncode(call.toJson())).toList();

      await prefs.setStringList(callHistoryKey, callHistoryJson);
      developer.log('Call history updated successfully');
    } catch (e) {
      developer.log('Error saving call to history: $e');
    }
  }

  // Method to get call history
  static Future<List<CallDetails>> getCallHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> callHistoryJson = prefs.getStringList(callHistoryKey) ?? [];

      List<CallDetails> callHistory = callHistoryJson
          .map((json) => CallDetails.fromJson(jsonDecode(json)))
          .toList();

      // Sort by created date (newest first)
      callHistory.sort((a, b) =>
          DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)));

      return callHistory;
    } catch (e) {
      developer.log('Error getting call history: $e');
      return [];
    }
  }

  // Method to update call details for all initiated calls
  static Future<void> refreshCallHistory() async {
    try {
      List<CallDetails> callHistory = await getCallHistory();

      for (var call in callHistory) {
        // Only refresh calls that are in initiated status
        if (call.status == 'initiated') {
          await getCallDetails(call.callId);
        }
      }
    } catch (e) {
      developer.log('Error refreshing call history: $e');
    }
  }

  // Method to delete a specific call from history
  static Future<bool> deleteCallFromHistory(String callId) async {
    try {
      developer.log('Deleting call from history: $callId');

      // Get current call history
      List<CallDetails> callHistory = await getCallHistory();

      // Find the call with matching ID to confirm it exists
      int index = callHistory.indexWhere((call) => call.callId == callId);

      if (index == -1) {
        developer.log('Call not found in history: $callId');
        return false;
      }

      // Remove the call with matching ID
      callHistory.removeAt(index);

      // Try to save to SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();

        // Save updated call history
        List<String> callHistoryJson =
            callHistory.map((call) => jsonEncode(call.toJson())).toList();

        await prefs.setStringList(callHistoryKey, callHistoryJson);
        developer.log('Call deleted from history successfully: $callId');
        return true;
      } catch (e) {
        developer.log('Error saving to SharedPreferences after deletion: $e');
        return false;
      }
    } catch (e) {
      developer.log('Error deleting call from history: $e');
      return false;
    }
  }

  // Method to clear all call history
  static Future<bool> clearAllCallHistory() async {
    try {
      developer.log('Clearing all call history');

      final prefs = await SharedPreferences.getInstance();
      bool success = await prefs.remove(callHistoryKey);

      if (success) {
        developer.log('All call history cleared successfully');
      } else {
        developer.log('Failed to clear call history');
      }

      return success;
    } catch (e) {
      developer.log('Error clearing call history: $e');
      return false;
    }
  }
}
