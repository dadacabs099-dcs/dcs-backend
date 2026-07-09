import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:Dadacabs/Container/Repositories/predicted_places_repo.dart';
import 'package:Dadacabs/View/Screens/Main_Screens/Sub_Screens/Where_To_Screen/where_to_logics.dart';
import 'package:Dadacabs/View/Widgets/translated_text.dart';

import 'where_to_providers.dart';

class WhereToScreen extends StatefulWidget {
  const WhereToScreen({super.key, required this.controller});

  final GoogleMapController controller;

  @override
  State<WhereToScreen> createState() => _WhereToScreenState();
}

class _WhereToScreenState extends State<WhereToScreen> {
  final TextEditingController whereToController = TextEditingController();

  late NavigatorState _navigator;

  @override
  void didChangeDependencies() {
    _navigator = Navigator.of(context);
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.sizeOf(context);
    return Scaffold(
      appBar: AppBar(
        foregroundColor: const Color(0xff1a3646),
        backgroundColor: const Color(0xff1a3646),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const TranslatedText(
          "Where To Go",
          style: TextStyle(fontFamily: "bold"),
        ),
      ),
      body: SafeArea(
          child: SizedBox(
        width: size.width,
        height: size.height,
        child: Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: Consumer(
            builder: (context, ref, child) {
              return Column(
                children: [
                  SizedBox(
                    width: size.width * 0.9,
                    child: TextField(
                      onChanged: (e) {
                        if (e.length < 2) {
                          ref
                              .watch(whereToPredictedPlacesProvider.notifier)
                              .update((state) => null);
                        }
                        ref
                            .watch(globalPredictedPlacesRepoProvider)
                            .getAllPredictedPlaces(e, context, ref);
                      },
                      controller: whereToController,
                      cursorColor: Colors.red,
                      keyboardType: TextInputType.text,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .copyWith(fontSize: 14),
                        decoration: InputDecoration(
                          label: const TranslatedText("Search Location"),
                          hint: TranslatedText(
                          'Search Location',
                          style: Theme.of(context)
                            .textTheme
                            .bodySmall!
                            .copyWith(fontSize: 14, color: Colors.white),
                          ),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: Colors.red, width: 1)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: Colors.red, width: 1))),
                    ),
                  ),
                  Expanded(
                    child: ref.watch(whereToPredictedPlacesProvider) == null
                        ? Container(
                            alignment: Alignment.center,
                            child: const TranslatedText(
                                "Please Write Something to start the search"))
                        : Container(
                            alignment: Alignment.center,
                            margin: const EdgeInsets.only(top: 15.0),
                            child: ref.watch(whereToLoadingProvider)
                                ? const CircularProgressIndicator.adaptive(
                                    backgroundColor: Colors.red,
                                  )
                                : ListView.separated(
                                    itemCount: ref
                                        .watch(whereToPredictedPlacesProvider)!
                                        .length,
                                    separatorBuilder: (context, index) {
                                      return const Divider(
                                        height: 20,
                                        color: Colors.red,
                                      );
                                    },
                                    itemBuilder: (context, index) {
                                      final place = ref
                                          .watch(whereToPredictedPlacesProvider)![
                                              index];
                                      return InkWell(
                                        onTap: () async {
                                          try {
                                            await WhereToLogics()
                                                .setDropOffLocation(
                                                    context,
                                                    ref,
                                                    widget.controller,
                                                    index);

                                            _navigator.pop();
                                          } catch (e) {
                                            print(e);
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                place.mainText ?? "Loading ...",
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              if (place.secText != null)
                                                const SizedBox(height: 4),
                                              if (place.secText != null)
                                                Text(
                                                  place.secText!,
                                                  style: TextStyle(
                                                      color: Colors.grey[300],
                                                      fontSize: 13),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                  )
                ],
              );
            },
          ),
        ),
      )),
    );
  }
}
