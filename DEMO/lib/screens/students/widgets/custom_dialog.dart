
import 'package:flutter/material.dart';
import 'package:school_manager/constants/colors.dart';
import 'package:school_manager/constants/sizes.dart';
import 'form_field.dart';

class CustomDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final VoidCallback onSubmit;
  final List<Map<String, String>> fields;

  const CustomDialog({
    required this.title,
    required this.content,
    required this.onSubmit,
    this.fields = const [], required List<ButtonStyleButton> actions,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge!.color,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Container(
          width: AppSizes.dialogWidth,
          child: content,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Annuler',
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color),
          ),
        ),
        ElevatedButton(
          onPressed: onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text('Ajouter'),
        ),
      ],
    );
  }
}