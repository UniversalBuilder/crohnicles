import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Reusable glassmorphic dialog wrapper with gradient header
/// Provides consistent 2026 Sci-Fi Cyber aesthetic across all dialogs
class GlassmorphicDialog extends StatelessWidget {
  final Gradient headerGradient;
  final IconData headerIcon;
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final double maxWidth;
  final double maxHeight;

  const GlassmorphicDialog({
    super.key,
    required this.headerGradient,
    required this.headerIcon,
    required this.title,
    required this.content,
    this.actions,
    this.maxWidth = 600,
    this.maxHeight = 700,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.95),
                AppColors.surfaceGlass.withValues(alpha: 0.90),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Gradient header
                _buildHeader(context),
                
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: content,
                  ),
                ),
                
                // Actions
                if (actions != null && actions!.isNotEmpty)
                  _buildActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: headerGradient,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          // Icon container with white glass effect
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Icon(
              headerIcon,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          
          // Title
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: actions!.map((action) {
          return Padding(
            padding: const EdgeInsets.only(left: 12),
            child: action,
          );
        }).toList(),
      ),
    );
  }
}

/// Gradient button for dialog actions
class GradientDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Gradient? gradient;
  final Color? textColor;
  final bool isPrimary;

  const GradientDialogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.gradient,
    this.textColor,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPrimary) {
      // Secondary button (text only)
      return TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryStart,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      );
    }

    // Primary button with gradient
    final buttonGradient = gradient ?? AppColors.primaryGradient;
    
    return Container(
      decoration: BoxDecoration(
        gradient: buttonGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (gradient == AppColors.mealGradient
                    ? AppColors.mealStart
                    : gradient == AppColors.painGradient
                        ? AppColors.painStart
                        : gradient == AppColors.stoolGradient
                            ? AppColors.stoolStart
                            : AppColors.primaryStart)
                .withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: Text(
              label,
              style: TextStyle(
                color: textColor ?? Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
