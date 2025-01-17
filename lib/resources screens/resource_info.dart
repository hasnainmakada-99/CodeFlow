import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // Import the url_launcher package
import 'package:codeflow/auth%20and%20cloud/auth_provider.dart';
import 'package:codeflow/screens/chat_screen.dart';
import 'package:codeflow/screens/feedback_screen.dart';
import 'package:expandable/expandable.dart'; // Import Expandable

class ResourceInfo extends ConsumerStatefulWidget {
  final String resourceTitle;
  final String resourceURL;
  final String resourceDescription;
  final String channelName;
  final DateTime publishedDate;
  final String resourceRelatedTo;

  const ResourceInfo({
    Key? key,
    required this.resourceURL,
    required this.resourceDescription,
    required this.resourceTitle,
    required this.channelName,
    required this.publishedDate,
    required this.resourceRelatedTo,
  }) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ResourceInfoState();
}

class _ResourceInfoState extends ConsumerState<ResourceInfo>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late YoutubePlayerController _youtubeController;
  late ExpandableController _expandableController;

  @override
  void initState() {
    super.initState();

    // Initialize YouTubePlayerController
    _youtubeController = YoutubePlayerController(
      initialVideoId: YoutubePlayer.convertUrlToId(widget.resourceURL) ??
          'default_video_id', // Provide a fallback video ID
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        forceHD: true,
        controlsVisibleAtStart: true,
      ),
    );

    // Initialize ExpandableController
    _expandableController = ExpandableController();

    _tabController = TabController(length: 2, vsync: this);
  }

  final DateFormat formatter = DateFormat('dd/MM/yyyy');

  // Function to detect links in the text and return them as a clickable widget
  Widget _buildDescriptionWithLinks(String description) {
    final RegExp urlRegExp = RegExp(r'http[s]?://[^\s]+');
    final Iterable<Match> matches = urlRegExp.allMatches(description);
    List<TextSpan> children = [];
    int lastMatchEnd = 0;

    // Iterate over all matches and create clickable widgets for URLs
    for (Match match in matches) {
      if (match.start > lastMatchEnd) {
        children.add(TextSpan(
          text: description.substring(lastMatchEnd, match.start),
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 18),
        ));
      }
      children.add(TextSpan(
        text: description.substring(match.start, match.end),
        style: GoogleFonts.poppins(
          color: Colors.blue,
          fontSize: 18,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            _launchURL(description.substring(match.start, match.end));
          },
      ));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < description.length) {
      children.add(TextSpan(
        text: description.substring(lastMatchEnd),
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 18),
      ));
    }

    return RichText(
      text: TextSpan(children: children),
    );
  }

  // Function to launch URLs
  Future<void> _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authRepositoryController = ref.watch(authRepositoryProvider);

    return YoutubePlayerBuilder(
      onExitFullScreen: () {
        // The player forces portraitUp after exiting fullscreen. This overrides the behaviour.
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      },
      player: YoutubePlayer(
        controller: _youtubeController,
        showVideoProgressIndicator: true,
      ),
      builder: (context, player) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(
              widget.resourceTitle,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(
                    text: 'Video',
                  ),
                  Tab(text: "Chat"),
                ],
                labelColor: Colors.black,
                unselectedLabelColor: Colors.black,
                indicatorColor: Colors.blueAccent,
                indicatorWeight: 3,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        // Display the YouTube Player
                        player,
                        const SizedBox(height: 16),
                        ExpandableNotifier(
                          controller: _expandableController,
                          child: Expandable(
                            collapsed: Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: _buildDescriptionWithLinks(
                                  widget.resourceDescription),
                            ),
                            expanded: Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: _buildDescriptionWithLinks(
                                  widget.resourceDescription),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Publisher: ${widget.channelName}',
                          style: GoogleFonts.poppins(
                            textStyle: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Published Date: ${formatter.format(widget.publishedDate)}",
                          style: GoogleFonts.poppins(
                            textStyle: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FeedbackScreen(
                                  resourceRelatedTo: widget.resourceRelatedTo,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            textStyle: const TextStyle(fontSize: 16),
                            backgroundColor: Colors.black,
                          ),
                          child: const Text(
                            'Give Feedback on this Resource',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    ChatScreen1(
                      userEmail: authRepositoryController.userEmail!,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _youtubeController.dispose();
    _expandableController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}
