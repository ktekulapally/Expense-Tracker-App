import 'package:flutter/material.dart';
import 'theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool? isPositive;
  final AppThemeColors colors;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.isPositive,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    Color valColor = colors.ink;
    if (isPositive == true) {
      valColor = colors.green;
    } else if (isPositive == false) {
      valColor = colors.red;
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: AppTheme.cardDecoration(colors),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTheme.getBodyStyle(colors, soft: true, size: 11, weight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppTheme.getMonoStyle(colors, size: 16, weight: FontWeight.w600).copyWith(
                color: valColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isGhost;
  final bool isDanger;
  final bool isLoading;
  final AppThemeColors colors;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isPrimary = true,
    this.isGhost = false,
    this.isDanger = false,
    this.isLoading = false,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    if (isGhost) {
      return TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: isDanger ? colors.red : colors.brassDark,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: isLoading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(text, style: AppTheme.getBodyStyle(colors, weight: FontWeight.w600, size: 13).copyWith(
                color: isDanger ? colors.red : colors.brassDark,
              )),
      );
    }

    final Color bgColor = isDanger
        ? colors.red
        : (isPrimary ? colors.ink : Colors.transparent);
    final Color fgColor = isPrimary ? Colors.white : colors.ink;
    final BorderSide border = isPrimary ? BorderSide.none : BorderSide(color: colors.paperLine);

    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        side: border,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: isLoading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(
              text,
              style: AppTheme.getBodyStyle(colors, weight: FontWeight.w600, size: 14).copyWith(
                color: fgColor,
              ),
            ),
    );
  }
}

class AppTextField extends StatelessWidget {
  final String label;
  final String? placeholder;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final AppThemeColors colors;
  final VoidCallback? onTap;
  final bool readOnly;

  const AppTextField({
    super.key,
    required this.label,
    this.placeholder,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.suffixIcon,
    required this.colors,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.getBodyStyle(colors, soft: true, size: 11, weight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          readOnly: readOnly,
          onTap: onTap,
          style: AppTheme.getBodyStyle(colors, size: 14),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: AppTheme.getBodyStyle(colors, soft: true, size: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: suffixIcon,
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: colors.paperLine),
              borderRadius: BorderRadius.circular(4),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: colors.ink),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }
}

class AppDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final AppThemeColors colors;

  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.getBodyStyle(colors, soft: true, size: 11, weight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colors.paperLine),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: colors.inkSoft),
              style: AppTheme.getBodyStyle(colors, size: 14),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  required AppThemeColors colors,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: AppTheme.getSubHeadingStyle(colors)),
      content: Text(content, style: AppTheme.getBodyStyle(colors)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: colors.card,
      actions: [
        AppButton(
          text: "Cancel",
          isPrimary: false,
          colors: colors,
          onPressed: () => Navigator.pop(context, false),
        ),
        AppButton(
          text: "Delete",
          isDanger: true,
          colors: colors,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
}
