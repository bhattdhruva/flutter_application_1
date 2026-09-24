import 'package:flutter/material.dart';

class CustomSearchHeader extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData titleIcon;
  final String? secondaryTabTitle;
  final IconData? secondaryTabIcon;
  final String searchHint;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSecondaryTabTap;

  const CustomSearchHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.titleIcon = Icons.people,
    this.secondaryTabTitle,
    this.secondaryTabIcon,
    this.searchHint = 'Search...',
    this.onSearchChanged,
    this.onSecondaryTabTap,
  });

  @override
  State<CustomSearchHeader> createState() => _CustomSearchHeaderState();
}

class _CustomSearchHeaderState extends State<CustomSearchHeader> with SingleTickerProviderStateMixin {
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchOpen = !_isSearchOpen;
    });

    if (_isSearchOpen) {
      _searchFocusNode.requestFocus();
    } else {
      _searchFocusNode.unfocus();
      _searchController.clear();
      widget.onSearchChanged?.call('');
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2E66F6);
    const secondaryBlue = Color(0xFF1E53E5);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Blue Header Container
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [primaryBlue, secondaryBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                // ignore: deprecated_member_use
                color: primaryBlue.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 32, // Extra padding at bottom for overlapping FAB
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Row: Title + Optional Secondary Tab
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Primary Title with Icon
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          // ignore: deprecated_member_use
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          widget.titleIcon,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),

                  // Optional Secondary Tab / Filter (e.g. Stories)
                  if (widget.secondaryTabTitle != null)
                    InkWell(
                      onTap: widget.onSecondaryTabTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          // ignore: deprecated_member_use
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            if (widget.secondaryTabIcon != null) ...[
                              Icon(
                                widget.secondaryTabIcon,
                                // ignore: deprecated_member_use
                                color: Colors.white.withOpacity(0.85),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              widget.secondaryTabTitle!,
                              style: TextStyle(
                                // ignore: deprecated_member_use
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Expandable Search Bar or Subtitle Count
              AnimatedCrossFade(
                firstChild: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: widget.subtitle != null
                      ? Text(
                          widget.subtitle!,
                          style: TextStyle(
                            // ignore: deprecated_member_use
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                secondChild: Container(
                  margin: const EdgeInsets.only(top: 8, right: 36), // Avoid overlapping search FAB
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        // ignore: deprecated_member_use
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: widget.onSearchChanged,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: primaryBlue, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                widget.onSearchChanged?.call('');
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                crossFadeState: _isSearchOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
            ],
          ),
        ),

        // Floating Circular Search Button positioned on the bottom right edge
        Positioned(
          right: 20,
          bottom: 10,
          child: GestureDetector(
            onTap: _toggleSearch,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 12,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _isSearchOpen ? Icons.close : Icons.search,
                color: primaryBlue,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
