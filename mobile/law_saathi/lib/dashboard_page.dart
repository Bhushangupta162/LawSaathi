import 'package:flutter/material.dart';
import 'api_helper.dart';
import 'package:intl/intl.dart';

import 'call_details.dart';
import 'recent_activity_page.dart';

class DashboardPage extends StatefulWidget {
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TextEditingController _phoneController = TextEditingController();
  late String _greeting;
  List<CallDetails> _callHistory = [];
  bool _isLoading = false;
  bool _shouldRefreshCallDetails = false;

  
  static const Color primaryGreen = Color(0xff235543);
  static const Color lightGreen = Color(0xff75e4bb);
  static const Color backgroundGreen = Color(0xfff0f8f5);

  @override
  void initState() {
    super.initState();
    _updateGreeting();
    _loadCallHistory(fetchDetails: false);
  }

  Future<void> _loadCallHistory({bool fetchDetails = false}) async {
    setState(() {
      _isLoading = true;
    });

    
    if (fetchDetails) {
      await ApiHelper.refreshCallHistory();
    }

    
    List<CallDetails> history = await ApiHelper.getCallHistory();

    setState(() {
      _callHistory = history;
      _isLoading = false;
    });
  }

  void _updateGreeting() {
    final currentTime = DateTime.now().hour;
    if (currentTime < 12) {
      _greeting = 'Good Morning';
    } else if (currentTime < 17) {
      _greeting = 'Good Afternoon';
    } else {
      _greeting = 'Good Evening';
    }
  }

  Future<void> _handleCallButtonPressed() async {
    String phoneNumber = _phoneController.text;

    
    if (phoneNumber.isEmpty) {
      _showCustomSnackBar("Please enter a phone number", isError: true);
      return;
    }

    
    String digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.length < 10) {
      _showCustomSnackBar("Phone number must be 10 digits", isError: true);
      return;
    }

    
    String formattedNumber = "+91" + digitsOnly;

    
    _showCustomSnackBar("Initiating call to $formattedNumber...");

    
    String? callId = await ApiHelper.makePhoneCall(formattedNumber);

    if (callId != null) {
      
      _loadCallHistory(fetchDetails: false);

      
      _showCustomSnackBar("Call initiated successfully");

      
      _shouldRefreshCallDetails = true;
    } else {
      _showCustomSnackBar("Failed to initiate call. Please try again.",
          isError: true);
    }
  }

  void _showCustomSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        backgroundColor: isError ? Colors.redAccent : primaryGreen,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  String _formatDateTime(String isoString) {
    try {
      
      DateTime dateTime;

      try {
        
        dateTime = DateTime.parse(isoString);
      } catch (e) {
        
        

        
        String simplifiedString = isoString;
        if (isoString.contains('+')) {
          simplifiedString = isoString.substring(0, isoString.indexOf('+'));
        } else if (isoString.contains('Z')) {
          simplifiedString = isoString.substring(0, isoString.indexOf('Z'));
        }

        
        dateTime = DateTime.parse(simplifiedString);
      }

      
      dateTime = dateTime.toLocal();

      
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
      
      print('Error parsing date: $e for input: $isoString');
      return "Unknown date";
    }
  }

  
  String _truncateSummary(String summary, int maxLength) {
    if (summary.length <= maxLength) {
      return summary;
    }
    return "${summary.substring(0, maxLength)}...";
  }

  
  Future<void> _handleViewCallHistory() async {
    
    setState(() {
      _isLoading = true;
    });

    try {
      
      if (_shouldRefreshCallDetails ||
          _callHistory.any((call) => call.status == 'initiated')) {
        await ApiHelper.refreshCallHistory();
        _shouldRefreshCallDetails = false;
      }

      
      List<CallDetails> history = await ApiHelper.getCallHistory();

      setState(() {
        _callHistory = history;
      });

      
      
    } catch (e) {
      _showCustomSnackBar("Failed to refresh call details. Please try again.",
          isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGreen,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        toolbarHeight: 120,
        title: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _greeting,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const Text(
                    'Daksh!',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryGreen, width: 2),
                  color: Colors.white,
                ),
                child: const CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 24,
                  child: Icon(
                    Icons.person,
                    size: 36,
                    color: primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: RefreshIndicator(
          onRefresh: () => _loadCallHistory(fetchDetails: false),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xffAED7C5),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Get connected to LawSaathi via call",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff235543),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: <Widget>[
                                
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 16),
                                  child: Row(
                                    children: [
                                      const Text(
                                        "+91",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: primaryGreen,
                                        ),
                                      ),
                                      
                                      Container(
                                        height: 24,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        width: 1,
                                        color: Colors.grey.withOpacity(0.3),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _phoneController,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter your phone number',
                                      hintStyle: TextStyle(
                                        color: Colors.black38,
                                        fontSize: 16,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 0, vertical: 16),
                                    ),
                                    keyboardType: TextInputType.phone,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: _handleCallButtonPressed,
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: primaryGreen,
                                      ),
                                      child: const Icon(
                                        Icons.phone_forwarded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "By Category",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff235543),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildCategoryButton('Criminal'),
                            const SizedBox(width: 12),
                            _buildCategoryButton('Medical'),
                            const SizedBox(width: 12),
                            _buildCategoryButton('Property'),
                            const SizedBox(width: 12),
                            _buildCategoryButton('Tax'),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Suggested Lawyers",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff235543),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildLawyerCard("assets/images/l1.png"),
                            const SizedBox(width: 16),
                            _buildLawyerCard("assets/images/l2.png"),
                            const SizedBox(width: 16),
                            _buildLawyerCard("assets/images/l3.png"),
                            const SizedBox(width: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  "Your recent activity",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xff235543),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  decoration: BoxDecoration(
                                    color: primaryGreen.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.refresh,
                                      size: 18,
                                      color: primaryGreen,
                                    ),
                                    onPressed: _handleViewCallHistory,
                                    tooltip: "Refresh call details",
                                  ),
                                ),
                              ]),
                          const SizedBox(height: 16),
                          _isLoading
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(
                                      color: primaryGreen,
                                    ),
                                  ),
                                )
                              : _callHistory.isEmpty
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text(
                                          "No recent activity",
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Column(
                                      children: _callHistory
                                          .take(
                                              3) 
                                          .map((call) => Column(
                                                children: [
                                                  _buildCallHistoryItem(call),
                                                  const SizedBox(height: 20),
                                                ],
                                              ))
                                          .toList(),
                                    ),
                          

                          if (!_isLoading && _callHistory.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        RecentActivityPage(),
                                  ),
                                ).then((_) {
                                  
                                  _loadCallHistory(fetchDetails: false);
                                });
                              },
                              style: TextButton.styleFrom(
                                backgroundColor:
                                    primaryGreen.withOpacity(0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                minimumSize: const Size(
                                    double.infinity, 0), 
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "View all your activity",
                                    style: TextStyle(
                                      color: primaryGreen,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                    color: primaryGreen,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryButton(String label) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: primaryGreen,
        elevation: 0,
        side: const BorderSide(width: 1.5, color: primaryGreen),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLawyerCard(String imagePath) {
    return Container(
      width: 160,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  

  Widget _buildCallHistoryItem(CallDetails call) {
    String displayPhoneNumber =
        call.phoneNumber.replaceAll(RegExp(r'\+91'), '');
    String title;
    IconData iconData;

    
    if (call.status == 'completed') {
      iconData = Icons.phone;
      title = "Call with LawSaathi";
      if (call.summary.isNotEmpty && call.summary != 'No summary available') {
        title += " - ${_truncateSummary(call.summary, 30)}";
      } else {
        title += " to $displayPhoneNumber";
      }
    } else if (call.status == 'initiated') {
      iconData = Icons.phone_forwarded;
      title = "Call to $displayPhoneNumber";
    } else {
      iconData = Icons.phone_missed;
      title = "Missed call to $displayPhoneNumber";
    }

    return InkWell(
      onTap: () {
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CallDetailsPage(callDetails: call),
          ),
        ).then((_) {
          
          _loadCallHistory(fetchDetails: false);
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: lightGreen.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                color: primaryGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${_formatDateTime(call.createdAt)}${call.callLength > 0 ? ' • ${call.callLength.toStringAsFixed(1)} min' : ''}",
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            
            call.status == 'initiated'
                ? Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "PENDING",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                  )
                : Icon(
                    call.status == 'completed'
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    size: 16,
                    color: call.status == 'completed'
                        ? primaryGreen
                        : Colors.redAccent,
                  ),
          ],
        ),
      ),
    );
  }
}
