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

  Future<void> refreshVideos() async {
    setState(() {
      ref.refresh(coursesProvider(selectedFilter));
    });
  }

  void _onFilterChanged(String? newFilter) {
    if (newFilter != null) {
      setState(() {
        selectedFilter = newFilter;
      });
    }
  }

  Future<bool> _showConfirmationDialog(String courseName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Action'),
          content: Text(
              'Are you sure you want to view or interact with $courseName?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Proceed'),
            ),
          ],
        );
      },
    );
    return confirm ?? false;
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
              onRefresh: refreshVideos,
              child: coursesAsyncValue.when(
                data: (courses) {
                  if (courses.isEmpty) {
                    return const Center(child: Text("No resources available"));
                  }
                  return ListView.builder(
                    itemCount: courses.length,
                    itemBuilder: (context, index) {
                      final snapshotData = courses[index];
                      return ResourceCard(
                        navigateTo: () async {
                          final shouldNavigate =
                              await _showConfirmationDialog(snapshotData.title);
                          if (shouldNavigate) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ResourceInfo(
                                  resourceRelatedTo: snapshotData.toolRelatedTo,
                                  channelName: snapshotData.channelName,
                                  publishedDate:
                                      snapshotData.publishedDate.toUtc(),
                                  resourceTitle: snapshotData.title,
                                  resourceURL: snapshotData.url,
                                  resourceDescription: snapshotData.description,
                                ),
                              ),
                            );
                          }
                        },
                        price: snapshotData.price,
                        imageUrl: snapshotData.thumbnail,
                        title: snapshotData.title,
                        description: snapshotData.description,
                        shareLink: snapshotData.url,
                        courseId: snapshotData.id,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: DropdownButton<String>(
        value: selectedFilter,
        hint: const Text('Select a filter'),
        onChanged: _onFilterChanged,
        items: const [
          DropdownMenuItem(
              value: 'All Resources', child: Text('All Resources')),
          DropdownMenuItem(value: 'Jenkins', child: Text('Jenkins')),
          DropdownMenuItem(value: 'Aws', child: Text('Aws')),
          DropdownMenuItem(value: 'Terraform', child: Text('Terraform')),
        ],
      ),
    );
  }
}
