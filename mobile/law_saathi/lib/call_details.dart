import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_helper.dart';
import 'dart:async';
// Import the new TranslationApiHelper instead
import 'translation_api_helper.dart';

class CallDetailsPage extends StatefulWidget {
  final CallDetails callDetails;
  const CallDetailsPage({Key? key, required this.callDetails})
      : super(key: key);
  @override
  State<CallDetailsPage> createState() => _CallDetailsPageState();
}

class _CallDetailsPageState extends State<CallDetailsPage> {
  bool _isLoading = false;
  bool _isTranslating = false;
  late CallDetails _callDetails;
  String _translatedSummary = '';
  String _selectedLanguage = 'Original';

  // Use the supported languages from TranslationApiHelper
  final List<String> _supportedLanguages =
      TranslationApiHelper.supportedLanguages;

  // Define our color scheme constants
  static const Color primaryGreen = Color(0xff235543);
  static const Color lightGreen = Color(0xff75e4bb);
  static const Color backgroundGreen = Color(0xfff0f8f5);

  @override
  void initState() {
    super.initState();
    _callDetails = widget.callDetails;
    // If the call is still in "initiated" status, refresh its details
    if (_callDetails.status == 'initiated') {
      _refreshCallDetails();
    }
  }

  Future<void> _refreshCallDetails() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final updatedDetails =
          await ApiHelper.getCallDetails(_callDetails.callId);
      if (updatedDetails != null) {
        setState(() {
          _callDetails = updatedDetails;
          // Reset to original language when details are refreshed
          _selectedLanguage = 'Original';
          _translatedSummary = '';
        });
      }
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh call details'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Updated function to translate the summary using the new TranslationApiHelper
  Future<void> _translateSummary(String language) async {
    if (_isTranslating ||
        _callDetails.summary.isEmpty ||
        _callDetails.summary == 'No summary available') {
      // If already translating or summary is empty, do nothing
      return;
    }

    // Handle Original language selection immediately
    if (language == 'Original') {
      setState(() {
        _selectedLanguage = 'Original';
        _translatedSummary = '';
      });
      return;
    }

    setState(() {
      _isTranslating = true;
      _selectedLanguage = language; // Update selected language immediately
    });

    try {
      // Use the new TranslationApiHelper
      final translatedText = await TranslationApiHelper.translateText(
          _callDetails.summary, language);

      setState(() {
        _translatedSummary = translatedText;
        _isTranslating = false;
      });
    } catch (e) {
      print('Translation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to translate summary'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isTranslating = false;
      });
    }
  }

  String _formatDateTime(String isoString) {
    try {
      // Handle ISO 8601 format with timezone information
      DateTime dateTime;
      try {
        // First try standard parsing
        dateTime = DateTime.parse(isoString);
      } catch (e) {
        // If standard parsing fails, try manually handling the format
        // For timestamps like: 2025-04-13T09:23:47.948+00:00
        // Remove the timezone part if it's causing issues
        String simplifiedString = isoString;
        if (isoString.contains('+')) {
          simplifiedString = isoString.substring(0, isoString.indexOf('+'));
        } else if (isoString.contains('Z')) {
          simplifiedString = isoString.substring(0, isoString.indexOf('Z'));
        }
        // Try parsing again
        dateTime = DateTime.parse(simplifiedString);
      }
      // Convert to local time for display
      dateTime = dateTime.toLocal();
      // Format based on how recent the date is
      DateTime now = DateTime.now();
      DateTime yesterday = now.subtract(const Duration(days: 1));
      if (dateTime.year == now.year &&
          dateTime.month == now.month &&
          dateTime.day == now.day) {
        return "Today, ${DateFormat('hh:mm a').format(dateTime)}";
      } else if (dateTime.year == yesterday.year &&
          dateTime.month == yesterday.month &&
          dateTime.day == yesterday.day) {
        return "Yesterday, ${DateFormat('hh:mm a').format(dateTime)}";
      } else {
        return DateFormat('MMM dd, hh:mm a').format(dateTime);
      }
    } catch (e) {
      // Log the error for debugging
      print('Error parsing date: $e for input: $isoString');
      return "Unknown date";
    }
  }

  // Function to display call status with appropriate color
  Widget _buildCallStatus(String status) {
    Color statusColor;
    String statusText;
    switch (status.toLowerCase()) {
      case 'completed':
        statusColor = Colors.green;
        statusText = 'Completed';
        break;
      case 'initiated':
        statusColor = Colors.orange;
        statusText = 'In Progress';
        break;
      case 'failed':
        statusColor = Colors.red;
        statusText = 'Failed';
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor, width: 1),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: statusColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Format phone number for display
    String displayPhoneNumber =
        _callDetails.phoneNumber.replaceAll(RegExp(r'\+91'), '');
    return Scaffold(
      backgroundColor: backgroundGreen,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryGreen),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Call Details',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_callDetails.status == 'initiated')
            IconButton(
              icon: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                      ))
                  : Icon(Icons.refresh, color: primaryGreen),
              onPressed: _isLoading ? null : _refreshCallDetails,
              tooltip: 'Refresh call details',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status and time
            Container(
              color: Colors.white,
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lightGreen.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.phone,
                      color: primaryGreen,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '+91 $displayPhoneNumber',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _formatDateTime(_callDetails.createdAt),
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Refresh icon at the end of the row
                  IconButton(
                    onPressed: _isLoading ? null : _refreshCallDetails,
                    icon: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(primaryGreen),
                            ),
                          )
                        : Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: lightGreen.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.refresh,
                              color: primaryGreen,
                              size: 20,
                            ),
                          ),
                    tooltip: 'Refresh call details',
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            // Call information card
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Call Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                        _buildCallStatus(_callDetails.status),
                      ],
                    ),
                    SizedBox(height: 20),
                    _buildInfoRow('Call ID', _callDetails.callId),
                    _buildDivider(),
                    _buildInfoRow(
                        'Duration',
                        _callDetails.callLength > 0
                            ? '${_callDetails.callLength.toStringAsFixed(1)} minutes'
                            : 'Not available'),
                    _buildDivider(),
                    _buildInfoRow('Phone Number', '+91 $displayPhoneNumber'),
                  ],
                ),
              ),
            ),
            // Call summary card
            if (_callDetails.summary.isNotEmpty &&
                _callDetails.summary != 'No summary available')
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Call Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                          ),
                          // Language dropdown
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: primaryGreen, width: 1),
                              color: Colors.white,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isDense: true,
                                value: _selectedLanguage,
                                icon: Icon(Icons.language,
                                    color: primaryGreen, size: 18),
                                items:
                                    _supportedLanguages.map((String language) {
                                  return DropdownMenuItem<String>(
                                    value: language,
                                    child: Text(
                                      language,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: primaryGreen,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    _translateSummary(newValue);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      if (_isTranslating)
                        Center(
                          child: Column(
                            children: [
                              SizedBox(height: 10),
                              CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(primaryGreen),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Translating to $_selectedLanguage...',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          _selectedLanguage == 'Original'
                              ? _callDetails.summary
                              : _translatedSummary,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            // Call again button
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: ElevatedButton(
                onPressed: () {
                  ApiHelper.makePhoneCall(_callDetails.phoneNumber);
                  Navigator.pop(context); // Return to the previous screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  minimumSize: Size(double.infinity, 0),
                ),
                child: Text(
                  'Call Again',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: Colors.grey.withOpacity(0.2),
      thickness: 1,
    );
  }
}
