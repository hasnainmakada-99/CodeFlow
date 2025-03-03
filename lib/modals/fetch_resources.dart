import 'dart:convert';

import 'package:codeflow/modals/courses_modal.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<List<Courses>> fetchCourses({String? filter}) async {
  var dio = Dio();
  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Set timeout and headers
  dio.options.connectTimeout = const Duration(seconds: 30);
  dio.options.receiveTimeout = const Duration(seconds: 30);
  dio.options.headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  try {
    print('Fetching resources from API...'); // Debug log

    final response = await dio.get(
      'https://codeflow-api.onrender.com/api/get-resources',
    );

    print('API response status: ${response.statusCode}'); // Debug log

    if (response.statusCode == 200) {
      if (response.data == null) {
        print('API returned null data');
        return loadCachedCourses(filter: filter);
      }

      List<dynamic> data = response.data;
      print('Fetched ${data.length} resources'); // Debug log

      // Cache the data
      prefs.setString('cachedCourses', jsonEncode(data));
      prefs.setString(
          'lastFetchTime', DateTime.now().toUtc().toIso8601String());

      try {
        List<Courses> courses =
            data.map((model) => Courses.fromJson(model)).toList();

        if (filter != null && filter.isNotEmpty && filter != 'All Resources') {
          courses = courses
              .where((course) =>
                  course.toolRelatedTo.toLowerCase() == filter.toLowerCase())
              .toList();
          print('Filter applied: $filter, found ${courses.length} courses');
        }

        return courses;
      } catch (parseError) {
        print('Error parsing data: $parseError');
        throw Exception('Failed to parse course data: $parseError');
      }
    } else if (response.statusCode == 304) {
      return loadCachedCourses(filter: filter);
    } else {
      print('API error: ${response.statusCode}');
      throw Exception('Failed to load courses: ${response.statusCode}');
    }
  } catch (error) {
    print('Error fetching data: $error');
    // Try to load from cache as fallback
    return loadCachedCourses(filter: filter);
  }
}

Future<List<Courses>> loadCachedCourses({String? filter}) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? cachedCourses = prefs.getString('cachedCourses');

  print('Loading cached courses, filter: $filter');

  if (cachedCourses != null) {
    try {
      Iterable list = jsonDecode(cachedCourses);
      List<Courses> courses =
          list.map((model) => Courses.fromJson(model)).toList();

      print('Loaded ${courses.length} cached courses');

      if (filter != null && filter.isNotEmpty && filter != 'All Resources') {
        courses = courses
            .where((course) =>
                course.toolRelatedTo.toLowerCase() == filter.toLowerCase())
            .toList();
        print('After filtering: ${courses.length} courses');
      }

      return courses;
    } catch (e) {
      print('Error parsing cached courses: $e');
      return [];
    }
  } else {
    print('No cached courses found');
    return [];
  }
}
