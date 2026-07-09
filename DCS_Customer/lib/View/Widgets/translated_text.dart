import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Dadacabs/Container/Services/translation_service.dart';

class Text extends ConsumerWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  const Text(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  @override
  Widget build(material.BuildContext context, WidgetRef ref) {
    final targetLang = ref.watch(appLanguageProvider);

    // Skip translation for English or empty strings
    if (targetLang == 'en' || data.isEmpty) {
      return material.Text(
        data,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
      );
    }

    return FutureBuilder<String>(
      future: TranslationService.translate(data, targetLang),
      builder: (context, snapshot) {
        String displayText = data;
        
        // Handle different snapshot states
        if (snapshot.hasData) {
          displayText = snapshot.data ?? data;
        } else if (snapshot.hasError) {
          // If translation fails, fall back to original text
          displayText = data;
        }
        // If still loading, show original text
        
        return material.Text(
          displayText,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
          softWrap: softWrap,
        );
      },
    );
  }
}

class TranslatedText extends Text {
  const TranslatedText(
    super.data, {
    super.key,
    super.style,
    super.textAlign,
    super.maxLines,
    super.overflow,
    super.softWrap,
  });
}
