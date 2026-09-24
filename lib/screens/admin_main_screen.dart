import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/admin_employee_details.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/widgets/custom_search_header.dart';
import 'package:flutter_application_1/widgets/floating_pill_nav_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;

  bool _isLoading = true;

  String? _errorMessage;

  String _companyName = '';

  String _companyId = '';

  List<Map<String, dynamic>> _employees = [];

  int _presentToday = 0;

  String _employeeSearchQuery = '';

  String _leaveSearchQuery = '';

  final List<Map<String, String>> _adminLeaveRequests = [];

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
  }

  // ============================================================
  // FETCH ADMIN DATA
  // ============================================================

  Future<void> _fetchAdminData() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      final supabase = Supabase.instance.client;

      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Admin is not logged in.');
      }

      // --------------------------------------------------------
      // 1. FIND ADMIN COMPANY
      // --------------------------------------------------------

      final adminRecord = await supabase
          .from('company_admins')
          .select('company_id')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (adminRecord == null) {
        throw Exception(
          'No company is assigned to this admin account.',
        );
      }

      final companyId = adminRecord['company_id'];

      // --------------------------------------------------------
      // 2. GET COMPANY
      // --------------------------------------------------------

      final company = await supabase
          .from('companies')
          .select('id, name')
          .eq('id', companyId)
          .single();

      // --------------------------------------------------------
      // 3. GET EMPLOYEES
      // --------------------------------------------------------
final employees = await supabase
    .from('employees')
    .select(
      'id, employee_code, full_name, company_id, auth_user_id',
    )
    .eq('company_id', companyId)
    .order('full_name');

      // --------------------------------------------------------
      // 4. GET TODAY'S ATTENDANCE
      // --------------------------------------------------------

      final now = DateTime.now();

      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      );

      final startOfNextDay = startOfDay.add(
        const Duration(days: 1),
      );

      final attendanceToday = await supabase
          .from('attendance')
          .select('employee_id')
          .eq('company_id', companyId)
          .gte(
            'punch_in',
            startOfDay.toUtc().toIso8601String(),
          )
          .lt(
            'punch_in',
            startOfNextDay.toUtc().toIso8601String(),
          );

      final Set<String> employeeIdsPresentToday = {};

      for (final record in attendanceToday) {
        final employeeId = record['employee_id'];

        if (employeeId != null) {
          employeeIdsPresentToday.add(
            employeeId.toString(),
          );
        }
      }

      // --------------------------------------------------------
      // 5. GET LEAVE REQUESTS
      // --------------------------------------------------------

      final companyIdString = companyId.toString();

      await _fetchLeaveRequests(companyIdString);

      if (!mounted) return;

      setState(() {
        _companyId = companyIdString;

        _companyName =
            company['name']?.toString() ?? '';

        _employees =
            List<Map<String, dynamic>>.from(
          employees,
        );

        _presentToday =
            employeeIdsPresentToday.length;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;

        _errorMessage = e.toString();

        _employees = [];

        _presentToday = 0;
      });
    }
  }

  // ============================================================
  // FETCH LEAVE REQUESTS
  // ============================================================

  Future<void> _fetchLeaveRequests(
    String companyId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      final leaveRequests = await supabase
          .from('leave_requests')
          .select(
            '''
            id,
            employee_id,
            company_id,
            leave_type,
            start_date,
            end_date,
            reason,
            status,
            admin_note,
            reviewed_by,
            reviewed_at,
            created_at,
            employee:employees(
              full_name,
              employee_code
            )
            ''',
          )
          .eq(
            'company_id',
            companyId,
          )
          .order(
            'created_at',
            ascending: false,
          );

      final List<Map<String, String>> loadedRequests = [];

      for (final record in leaveRequests) {
        final employee =
            record['employee'] as Map<String, dynamic>?;

        final startDate =
            record['start_date']?.toString() ?? '';

        final endDate =
            record['end_date']?.toString() ?? '';

        final rawStatus =
            record['status']?.toString() ?? 'pending';

        final status =
            _formatLeaveStatus(rawStatus);

        loadedRequests.add({
          'id': record['id']?.toString() ?? '',
          'employeeName':
              employee?['full_name']?.toString() ??
                  'Unknown Employee',
          'code':
              employee?['employee_code']?.toString() ??
                  '---',
          'type':
              record['leave_type']?.toString() ??
                  'Leave',
          'dates': _formatLeaveDates(
            startDate,
            endDate,
          ),
          'reason':
              record['reason']?.toString() ??
                  'No reason provided',
          'status': status,
          'adminNote':
              record['admin_note']?.toString() ?? '',
        });
      }

      if (!mounted) return;

      setState(() {
        _adminLeaveRequests.clear();

        _adminLeaveRequests.addAll(
          loadedRequests,
        );
      });
    } catch (e) {
      debugPrint(
        'Error loading leave requests: $e',
      );
    }
  }

  // ============================================================
  // FORMAT LEAVE DATES
  // ============================================================

  String _formatLeaveDates(
    String startDate,
    String endDate,
  ) {
    if (startDate.isEmpty) {
      return 'Date not available';
    }

    try {
      final start = DateTime.parse(
        startDate,
      );

      final end = DateTime.parse(
        endDate.isEmpty
            ? startDate
            : endDate,
      );

      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      final startText =
          '${months[start.month - 1]} '
          '${start.day}, '
          '${start.year}';

      final endText =
          '${months[end.month - 1]} '
          '${end.day}, '
          '${end.year}';

      if (startDate == endDate) {
        return startText;
      }

      return '$startText → $endText';
    } catch (_) {
      return '$startDate - $endDate';
    }
  }

  // ============================================================
  // FORMAT STATUS
  // ============================================================

  String _formatLeaveStatus(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Approved';

      case 'rejected':
        return 'Rejected';

      case 'pending':
      default:
        return 'Pending';
    }
  }

  // ============================================================
  // SHOW APPROVE / REJECT DIALOG
  // ============================================================

  Future<void> _showLeaveDecisionDialog(
    Map<String, String> request,
    String decision,
  ) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _LeaveDecisionDialog(
          employeeName:
              request['employeeName'] ??
                  'Employee',
          leaveType:
              request['type'] ??
                  'Leave',
          dates:
              request['dates'] ??
                  '',
          decision: decision,
        );
      },
    );

    if (result == null) {
      return;
    }

    await _updateLeaveStatus(
      request['id']!,
      decision,
      adminNote: result,
    );
  }

  // ============================================================
  // UPDATE LEAVE STATUS
  // ============================================================

  Future<void> _updateLeaveStatus(
    String id,
    String status, {
    String adminNote = '',
  }) async {
    try {
      final supabase =
          Supabase.instance.client;

      final user =
          supabase.auth.currentUser;

      if (user == null) {
        throw Exception(
          'Admin is not logged in.',
        );
      }

      // Convert UI value:
      //
      // Approved -> approved
      // Rejected -> rejected
      //
      // This matches the database status format.

      final databaseStatus =
          status.toLowerCase();

      await supabase
          .from('leave_requests')
          .update({
        'status': databaseStatus,
        'admin_note': adminNote.isEmpty
            ? null
            : adminNote,
        'reviewed_by': user.id,
        'reviewed_at': DateTime.now()
            .toUtc()
            .toIso8601String(),
      })
          .eq(
            'id',
            id,
          )
          .eq(
            'company_id',
            _companyId,
          );

      // Reload the real data from Supabase.
      await _fetchLeaveRequests(
        _companyId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Leave request marked as $status',
          ),
          backgroundColor:
              status == 'Approved'
                  ? Colors.green
                  : Colors.red,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Unable to update leave request: $e',
          ),
          backgroundColor: Colors.red,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    try {
      await Supabase.instance.client
          .auth
          .signOut();
    } catch (_) {}

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            const LogInScreen(),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8FAFC),

      body: SafeArea(
        child: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : _errorMessage != null
                ? _buildErrorScreen()
                : IndexedStack(
                    index: _currentIndex,
                    children: [
                      _buildDashboardTab(),
                      _buildEmployeesTab(),
                      _buildLeaveTab(),
                      _buildReportsTab(),
                    ],
                  ),
      ),

      bottomNavigationBar:
          FloatingPillNavBar(
        currentIndex: _currentIndex,

        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },

        items: const [
          FloatingNavItem(
            icon:
                Icons.dashboard_outlined,
            activeIcon:
                Icons.dashboard,
            label: 'Dashboard',
          ),
          FloatingNavItem(
            icon:
                Icons.people_outline,
            activeIcon:
                Icons.people,
            label: 'Employees',
          ),
          FloatingNavItem(
            icon:
                Icons.event_available_outlined,
            activeIcon:
                Icons.event_available,
            label: 'Leave',
          ),
          FloatingNavItem(
            icon:
                Icons.bar_chart_outlined,
            activeIcon:
                Icons.bar_chart,
            label: 'Reports',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR SCREEN
  // ============================================================

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 55,
            ),

            const SizedBox(height: 16),

            const Text(
              'Unable to load admin data',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              _errorMessage ??
                  'Unknown error',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Colors.grey.shade700,
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed:
                  _fetchAdminData,
              child:
                  const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DASHBOARD TAB
  // ============================================================

  Widget _buildDashboardTab() {
    final pendingCount =
        _adminLeaveRequests
            .where(
              (r) =>
                  r['status'] ==
                  'Pending',
            )
            .length;

    return ListView(
      padding:
          const EdgeInsets.all(16),
      children: [
        CustomSearchHeader(
          title: 'Admin Panel',
          subtitle:
              '$_companyName Dashboard',
          titleIcon:
              Icons.admin_panel_settings,
          secondaryTabTitle:
              'Profile',
          secondaryTabIcon:
              Icons.person,
          searchHint:
              'Search admin metrics...',
        ),

        const SizedBox(height: 20),

        Row(
          children: [
            _buildMetricCard(
              'Total Staff',
              '${_employees.length}',
              Icons.group,
              Colors.blue,
            ),

            const SizedBox(width: 12),

            _buildMetricCard(
              'Present Today',
              '$_presentToday',
              Icons.how_to_reg,
              Colors.green,
            ),

            const SizedBox(width: 12),

            _buildMetricCard(
              'Pending Leave',
              '$pendingCount',
              Icons.pending_actions,
              Colors.orange,
            ),
          ],
        ),

        const SizedBox(height: 24),

        const Text(
          'Pending Approvals',
          style: TextStyle(
            fontSize: 18,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        if (pendingCount == 0)
          const Card(
            child: Padding(
              padding:
                  EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'All leave requests processed!',
                ),
              ),
            ),
          )
        else
          ..._adminLeaveRequests
              .where(
                (r) =>
                    r['status'] ==
                    'Pending',
              )
              .map(
                (req) => Card(
                  margin:
                      const EdgeInsets.only(
                    bottom: 10,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      req['employeeName']!,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${req['type']} • ${req['dates']}\n'
                      'Reason: ${req['reason']}',
                    ),
                    trailing:
                        Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        IconButton(
                          icon:
                              const Icon(
                            Icons
                                .check_circle,
                            color:
                                Colors.green,
                          ),
                          onPressed: () =>
                              _showLeaveDecisionDialog(
                            req,
                            'Approved',
                          ),
                        ),
                        IconButton(
                          icon:
                              const Icon(
                            Icons.cancel,
                            color:
                                Colors.red,
                          ),
                          onPressed: () =>
                              _showLeaveDecisionDialog(
                            req,
                            'Rejected',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  // ============================================================
  // EMPLOYEES TAB
  // ============================================================

  Widget _buildEmployeesTab() {
    final filtered =
        _employees.where((emp) {
      final name =
          (emp['full_name'] ?? '')
              .toString()
              .toLowerCase();

      final code =
          (emp['employee_code'] ?? '')
              .toString()
              .toLowerCase();

      final query =
          _employeeSearchQuery
              .toLowerCase();

      return name.contains(query) ||
          code.contains(query);
    }).toList();

    return ListView(
      padding:
          const EdgeInsets.all(16),
      children: [
        CustomSearchHeader(
          title: 'People',
          subtitle:
              '${filtered.length} people in list',
          titleIcon:
              Icons.people,
          secondaryTabTitle:
              'Stories',
          secondaryTabIcon:
              Icons.grid_view_rounded,
          searchHint:
              'Search employees by name, code...',
          onSearchChanged: (query) {
            setState(() {
              _employeeSearchQuery =
                  query;
            });
          },
        ),

        const SizedBox(height: 24),

        if (filtered.isEmpty)
          const Padding(
            padding:
                EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No employees found matching search.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          )
        else
          ...filtered.map(
            (employee) {
              final name =
                  employee['full_name'] ??
                      'Unknown Employee';

              final employeeCode =
                  employee[
                          'employee_code'] ??
                      '';

              return Card(
                elevation: 2,
                margin:
                    const EdgeInsets.only(
                  bottom: 12,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    12,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            const Color(
                          0xFF2E66F6,
                        ),
                        child: Text(
                          name
                              .toString()
                              .substring(
                                0,
                                1,
                              )
                              .toUpperCase(),
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 14,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              name.toString(),
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),

                            const SizedBox(
                              height: 2,
                            ),

                            Text(
                              employeeCode
                                  .toString(),
                              style:
                                  TextStyle(
                                color: Colors
                                    .grey
                                    .shade600,
                                fontSize: 13,
                              ),
                            ),

                            const SizedBox(
                              height: 4,
                            ),

                            Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration:
                                  BoxDecoration(
                                color: Colors
                                    .blue
                                    .shade50,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  8,
                                ),
                              ),
                              child:
                                  const Text(
                                'Employee',
                                style:
                                    TextStyle(
                                  color:
                                      Color(
                                    0xFF2E66F6,
                                  ),
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
                        icon:
                            const Icon(
                          Icons
                              .arrow_forward_ios,
                          size: 16,
                          color:
                              Colors.grey,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdminEmployeeDetailsScreen(
                                employee:
                                    employee,
                                companyName:
                                    _companyName,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // ============================================================
  // LEAVE TAB
  // ============================================================

  Widget _buildLeaveTab() {
    final filtered =
        _adminLeaveRequests.where(
      (req) {
        final q =
            _leaveSearchQuery
                .toLowerCase();

        return req['employeeName']!
                .toLowerCase()
                .contains(q) ||
            req['code']!
                .toLowerCase()
                .contains(q) ||
            req['type']!
                .toLowerCase()
                .contains(q) ||
            req['status']!
                .toLowerCase()
                .contains(q);
      },
    ).toList();

    return ListView(
      padding:
          const EdgeInsets.all(16),
      children: [
        CustomSearchHeader(
          title: 'Leave Requests',
          subtitle:
              '${_adminLeaveRequests.length} total leave submissions',
          titleIcon:
              Icons.event_note,
          secondaryTabTitle:
              'All',
          searchHint:
              'Search leave requests by name or status...',
          onSearchChanged: (q) {
            setState(() {
              _leaveSearchQuery = q;
            });
          },
        ),

        const SizedBox(height: 20),

        if (filtered.isEmpty)
          const Padding(
            padding:
                EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No leave requests matching filter.',
              ),
            ),
          )
        else
          ...filtered.map(
            (req) => Card(
              margin:
                  const EdgeInsets.only(
                bottom: 12,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    // ------------------------------------------------
                    // EMPLOYEE + STATUS
                    // ------------------------------------------------

                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              const Color(
                            0xFF2E66F6,
                          ),
                          child: Text(
                            (req['employeeName'] ??
                                    'E')
                                .substring(
                              0,
                              1,
                            )
                                .toUpperCase(),
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: 12,
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                req['employeeName'] ??
                                    'Employee',
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),

                              const SizedBox(
                                height: 2,
                              ),

                              Text(
                                req['code'] ??
                                    '---',
                                style:
                                    TextStyle(
                                  color: Colors
                                      .grey
                                      .shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        _buildLeaveStatusChip(
                          req['status'] ??
                              'Pending',
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    // ------------------------------------------------
                    // LEAVE TYPE
                    // ------------------------------------------------

                    Text(
                      req['type'] ??
                          'Leave',
                      style:
                          const TextStyle(
                        color:
                            Color(0xFF2E66F6),
                        fontWeight:
                            FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    // ------------------------------------------------
                    // DATES
                    // ------------------------------------------------

                    Row(
                      children: [
                        Icon(
                          Icons
                              .calendar_today_outlined,
                          size: 16,
                          color: Colors
                              .grey
                              .shade600,
                        ),

                        const SizedBox(
                          width: 7,
                        ),

                        Expanded(
                          child: Text(
                            req['dates'] ??
                                '',
                            style:
                                TextStyle(
                              color: Colors
                                  .grey
                                  .shade700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    // ------------------------------------------------
                    // REASON
                    // ------------------------------------------------

                    Text(
                      'Reason:',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.w600,
                        color: Colors
                            .grey
                            .shade800,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      req['reason'] ??
                          'No reason provided',
                      style:
                          TextStyle(
                        color: Colors
                            .grey
                            .shade700,
                      ),
                    ),

                    // ------------------------------------------------
                    // ADMIN NOTE
                    // ------------------------------------------------

                    if ((req['adminNote'] ??
                            '')
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 12,
                      ),

                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets
                                .all(10),
                        decoration:
                            BoxDecoration(
                          color: Colors
                              .grey
                              .shade100,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
                        ),
                        child: Text(
                          'Admin note: ${req['adminNote']}',
                          style:
                              TextStyle(
                            color: Colors
                                .grey
                                .shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],

                    // ------------------------------------------------
                    // APPROVE / REJECT
                    // ------------------------------------------------

                    if (req['status'] ==
                        'Pending') ...[
                      const SizedBox(
                        height: 14,
                      ),

                      Row(
                        children: [
                          Expanded(
                            child:
                                ElevatedButton
                                    .icon(
                              onPressed: () =>
                                  _showLeaveDecisionDialog(
                                req,
                                'Approved',
                              ),
                              icon:
                                  const Icon(
                                Icons.check,
                                size: 18,
                              ),
                              label:
                                  const Text(
                                'Approve',
                              ),
                              style:
                                  ElevatedButton
                                      .styleFrom(
                                backgroundColor:
                                    Colors.green,
                                foregroundColor:
                                    Colors.white,
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  vertical: 12,
                                ),
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    10,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 12,
                          ),

                          Expanded(
                            child:
                                ElevatedButton
                                    .icon(
                              onPressed: () =>
                                  _showLeaveDecisionDialog(
                                req,
                                'Rejected',
                              ),
                              icon:
                                  const Icon(
                                Icons.close,
                                size: 18,
                              ),
                              label:
                                  const Text(
                                'Reject',
                              ),
                              style:
                                  ElevatedButton
                                      .styleFrom(
                                backgroundColor:
                                    Colors.red,
                                foregroundColor:
                                    Colors.white,
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  vertical: 12,
                                ),
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // LEAVE STATUS CHIP
  // ============================================================

  Widget _buildLeaveStatusChip(
    String status,
  ) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case 'Approved':
        backgroundColor =
            Colors.green.shade100;
        textColor =
            Colors.green.shade800;
        break;

      case 'Rejected':
        backgroundColor =
            Colors.red.shade100;
        textColor =
            Colors.red.shade800;
        break;

      default:
        backgroundColor =
            Colors.orange.shade100;
        textColor =
            Colors.orange.shade800;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration:
          BoxDecoration(
        color: backgroundColor,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontWeight:
              FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  // ============================================================
  // REPORTS TAB
  // ============================================================

  Widget _buildReportsTab() {
    return ListView(
      padding:
          const EdgeInsets.all(16),
      children: [
        CustomSearchHeader(
          title: 'Reports',
          subtitle:
              'Attendance & Analytics Summary',
          titleIcon:
              Icons.bar_chart,
          secondaryTabTitle:
              'Download',
          secondaryTabIcon:
              Icons.picture_as_pdf,
          onSecondaryTabTap: () {
            ScaffoldMessenger.of(
                    context)
                .showSnackBar(
              const SnackBar(
                content: Text(
                  'Report download will be connected to database reports.',
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        Card(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
          ),
          child: Padding(
            padding:
                const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                const Text(
                  'Monthly Attendance Overview',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                  child:
                      LinearProgressIndicator(
                    value: 0,
                    minHeight: 12,
                    backgroundColor:
                        Colors.grey
                            .shade200,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                const Text(
                  'Database reports coming next',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF2E66F6),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            _buildReportSummaryCard(
              'On-Time Arrival',
              '--',
              Icons.thumb_up,
              Colors.green,
            ),

            const SizedBox(
              width: 12,
            ),

            _buildReportSummaryCard(
              'Avg Daily Hrs',
              '--',
              Icons.access_time,
              Colors.indigo,
            ),
          ],
        ),

        const SizedBox(height: 20),

        Card(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
          ),
          child: const Padding(
            padding:
                EdgeInsets.all(20),
            child: Center(
              child: Text(
                'Reports will use real attendance data from Supabase.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color:
                      Colors.grey,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed: _logout,
          icon:
              const Icon(Icons.logout),
          label:
              const Text('Admin Logout'),
          style:
              ElevatedButton.styleFrom(
            backgroundColor:
                Colors.red.shade50,
            foregroundColor:
                Colors.red,
            padding:
                const EdgeInsets
                    .symmetric(
              vertical: 14,
            ),
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPLOYEE DETAILS MODAL
  // ============================================================

  void _showEmployeeDetailsModal(
    Map<String, dynamic> employee,
  ) {
    final name =
        employee['full_name'] ??
            'Employee';

    final code =
        employee['employee_code'] ??
            '---';

    showModalBottomSheet(
      context: context,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor:
                    const Color(
                  0xFF2E66F6,
                ),
                child: Text(
                  name
                      .toString()
                      .substring(
                        0,
                        1,
                      )
                      .toUpperCase(),
                  style:
                      const TextStyle(
                    fontSize: 28,
                    color:
                        Colors.white,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                name.toString(),
                style:
                    const TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              Text(
                'Employee Code: $code',
                style: TextStyle(
                  color:
                      Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 20),

              ListTile(
                leading:
                    const Icon(
                  Icons.badge,
                ),
                title:
                    const Text(
                  'Employee Code',
                ),
                subtitle:
                    Text(
                  code.toString(),
                ),
              ),

              ListTile(
                leading:
                    const Icon(
                  Icons.business,
                ),
                title:
                    const Text(
                  'Company',
                ),
                subtitle:
                    Text(
                  _companyName,
                ),
              ),

              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(
                  context,
                ),
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(
                    0xFF2E66F6,
                  ),
                  foregroundColor:
                      Colors.white,
                  minimumSize:
                      const Size(
                    double.infinity,
                    45,
                  ),
                ),
                child:
                    const Text(
                  'Close',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // METRIC CARD
  // ============================================================

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.all(12),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(0.04),
              blurRadius: 10,
              offset:
                  const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),

            const SizedBox(height: 8),

            Text(
              value,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              title,
              style: TextStyle(
                color: Colors
                    .grey
                    .shade600,
                fontSize: 11,
              ),
              textAlign:
                  TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REPORT SUMMARY CARD
  // ============================================================

  Widget _buildReportSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.all(16),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(0.04),
              blurRadius: 10,
              offset:
                  const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 28,
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    value,
                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors
                          .grey
                          .shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// LEAVE DECISION DIALOG
//
// IMPORTANT:
// This class is OUTSIDE _AdminMainScreenState.
// It owns its own TextEditingController.
// This fixes:
// "A TextEditingController was used after being disposed."
// ==================================================================

class _LeaveDecisionDialog
    extends StatefulWidget {
  final String employeeName;
  final String leaveType;
  final String dates;
  final String decision;

  const _LeaveDecisionDialog({
    required this.employeeName,
    required this.leaveType,
    required this.dates,
    required this.decision,
  });

  @override
  State<_LeaveDecisionDialog>
      createState() =>
          _LeaveDecisionDialogState();
}

class _LeaveDecisionDialogState
    extends State<_LeaveDecisionDialog> {
  late final TextEditingController
      _noteController;

  @override
  void initState() {
    super.initState();

    _noteController =
        TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isApprove =
        widget.decision ==
            'Approved';

    return AlertDialog(
      title: Text(
        isApprove
            ? 'Approve Leave'
            : 'Reject Leave',
      ),

      content:
          SingleChildScrollView(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            Text(
              widget.employeeName,
              style:
                  const TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 5,
            ),

            Text(
              widget.leaveType,
              style:
                  const TextStyle(
                color:
                    Color(0xFF2E66F6),
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              widget.dates,
              style: TextStyle(
                color:
                    Colors.grey.shade700,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            TextField(
              controller:
                  _noteController,
              maxLines: 3,
              textInputAction:
                  TextInputAction
                      .newline,
              decoration:
                  InputDecoration(
                labelText:
                    'Admin note',
                hintText:
                    'Optional note for employee',
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pop();
          },
          child:
              const Text(
            'Cancel',
          ),
        ),

        ElevatedButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pop(
              _noteController
                  .text
                  .trim(),
            );
          },
          style:
              ElevatedButton
                  .styleFrom(
            backgroundColor:
                isApprove
                    ? Colors.green
                    : Colors.red,
            foregroundColor:
                Colors.white,
          ),
          child: Text(
            isApprove
                ? 'Approve'
                : 'Reject',
          ),
        ),
      ],
    );
  }
}