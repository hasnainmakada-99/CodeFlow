import 'package:codeflow/auth%20and%20cloud/auth_provider.dart';
import 'package:codeflow/auth%20and%20cloud/cloud_provider.dart';
import 'package:codeflow/modals/courses_modal.dart';
import 'package:codeflow/modals/fetch_resources.dart';
import 'package:codeflow/resources%20screens/resource_info.dart';
import 'package:codeflow/utils/resource_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Modified provider to handle 'All Resources' case
final coursesProvider =
    FutureProvider.family<List<Courses>, String>((ref, filter) async {
  print('Fetching courses with filter: $filter');
  // If 'All Resources' is selected or filter is empty, fetch without a filter
  if (filter == 'All Resources' || filter.isEmpty) {
    return fetchCourses(); // Assuming your fetchCourses can work without a filter
  }
  return fetchCourses(filter: filter); // Otherwise, fetch with the filter
});

class AllResources extends ConsumerStatefulWidget {
  const AllResources({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _AllResourcesState();
}

class _AllResourcesState extends ConsumerState<AllResources> {
  String selectedFilter = 'All Resources'; // Set default to 'All Resources'

  Future<void> refreshResources() async {
    print('Refreshing resources with filter: $selectedFilter');
    setState(() {
      ref.refresh(coursesProvider(selectedFilter));
    });
  }

  void _onFilterChanged(String? newFilter) {
    if (newFilter != null) {
      print('Filter changed from $selectedFilter to $newFilter');
      setState(() {
        selectedFilter = newFilter;
      });
    }
  }

  Future<bool> _showConfirmationDialog(String courseName, bool isPaid) async {
    // Custom message based on whether course is paid or free
    final message = isPaid
        ? 'This is a premium course. You\'ll need to pay to access it. Continue?'
        : 'Are you sure you want to view or interact with $courseName?';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isPaid ? 'Premium Course' : 'Confirm Action'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(isPaid ? 'Continue' : 'Proceed'),
            ),
          ],
        );
      },
    );
    return confirm ?? false;
  }

  // Helper method to check if user can access content
  Future<bool> _checkPremiumAccess(Courses course) async {
    // If course is free, allow access
    if (!course.isPaid) return true;

    // If course is paid, check if user has access
    final user = ref.read(authStateChangesProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to access premium content')),
      );
      return false;
    }

    try {
      final isEnrolled =
          await ref.read(cloudProvider).checkEnrollment(course.id, user.uid);
      if (!isEnrolled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please enroll and pay to access this course')),
        );
        return false;
      }
      return true;
    } catch (e) {
      print('Error checking enrollment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error checking access permissions')),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsyncValue = ref.watch(coursesProvider(selectedFilter));

    return Scaffold(
      body: Column(
        children: [
          _buildFilterDropdown(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refreshResources,
              child: coursesAsyncValue.when(
                data: (courses) {
                  print('Received ${courses.length} courses');
                  courses.forEach((course) {
                    print(
                        'Course: ${course.title}, isPaid: ${course.isPaid}, price: ${course.price}');
                  });

                  if (courses.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            "No resources found",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: Colors.grey[700],
                            ),
                          ),
                          if (selectedFilter != 'All Resources')
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  selectedFilter = 'All Resources';
                                });
                              },
                              child: const Text("Show all resources"),
                            ),
                        ],
                      ),
                    );
                  }

                  // Show a summary of free vs paid courses
                  int paidCount =
                      courses.where((course) => course.isPaid).length;
                  int freeCount = courses.length - paidCount;

                  print(
                      'Summary: Free courses: $freeCount, Paid courses: $paidCount');

                  return Column(
                    children: [
                      // Stats bar for resources count
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: Colors.grey[100],
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total: ${courses.length} resources',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.money_off,
                                    size: 16, color: Colors.green[700]),
                                const SizedBox(width: 4),
                                Text(
                                  'Free: $freeCount',
                                  style: GoogleFonts.poppins(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.payments_outlined,
                                    size: 16, color: Colors.orange[700]),
                                const SizedBox(width: 4),
                                Text(
                                  'Paid: $paidCount',
                                  style: GoogleFonts.poppins(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Resources list
                      Expanded(
                        child: ListView.builder(
                          itemCount: courses.length,
                          itemBuilder: (context, index) {
                            final snapshotData = courses[index];
                            print(
                                'Building card for: ${snapshotData.title}, isPaid: ${snapshotData.isPaid}, price: ${snapshotData.price}');

                            return ResourceCard(
                              navigateTo: () async {
                                final shouldNavigate =
                                    await _showConfirmationDialog(
                                        snapshotData.title,
                                        snapshotData.isPaid);

                                if (!shouldNavigate) return;

                                // For paid courses, verify access before navigating
                                if (snapshotData.isPaid) {
                                  final hasAccess =
                                      await _checkPremiumAccess(snapshotData);
                                  if (!hasAccess) return;
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ResourceInfo(
                                      resourceRelatedTo:
                                          snapshotData.toolRelatedTo,
                                      channelName: snapshotData.channelName,
                                      publishedDate:
                                          snapshotData.publishedDate.toUtc(),
                                      resourceTitle: snapshotData.title,
                                      resourceURL: snapshotData.url,
                                      resourceDescription:
                                          snapshotData.description,
                                    ),
                                  ),
                                );
                              },
                              isPaid: snapshotData.isPaid,
                              price: snapshotData.price,
                              imageUrl: snapshotData.thumbnail,
                              title: snapshotData.title,
                              description: snapshotData.description,
                              shareLink: snapshotData.url,
                              courseId: snapshotData.id,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text("Loading resources..."),
                    ],
                  ),
                ),
                error: (error, stack) {
                  print('Error loading resources: $error');
                  print('Stack trace: $stack');

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red),
                        SizedBox(height: 16),
                        Text(
                          'Error loading resources',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(error.toString()),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: refreshResources,
                          child: Text("Try Again"),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            'Filter:',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              value: selectedFilter,
              isExpanded: true,
              underline: Container(),
              icon: const Icon(Icons.arrow_drop_down),
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontSize: 16,
              ),
              onChanged: _onFilterChanged,
              items: const [
                DropdownMenuItem(
                  value: 'All Resources',
                  child: Text('All Resources'),
                ),
                DropdownMenuItem(
                  value: 'Jenkins',
                  child: Text('Jenkins'),
                ),
                DropdownMenuItem(
                  value: 'Aws',
                  child: Text('AWS'),
                ),
                DropdownMenuItem(
                  value: 'Terraform',
                  child: Text('Terraform'),
                ),
                DropdownMenuItem(
                  value:
                      'Hasnain', // Added this filter option to match your test data
                  child: Text('Hasnain'),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: refreshResources,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }
}
