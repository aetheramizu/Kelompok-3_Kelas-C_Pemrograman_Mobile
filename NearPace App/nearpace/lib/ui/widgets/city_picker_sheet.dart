import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../domain/geo_point.dart';
import '../../services/indonesian_cities.dart';
import '../../state/nearpace_controller.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import 'nearpace_card.dart';

/// Searchable Indonesian City Picker bottom sheet with GPS auto-detection.
class CityPickerSheet extends StatefulWidget {
  const CityPickerSheet({
    super.key,
    this.currentCity,
    this.title = 'Select City',
  });

  final String? currentCity;
  final String title;

  static Future<String?> show(
    BuildContext context, {
    String? currentCity,
    String title = 'Select City',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CityPickerSheet(currentCity: currentCity, title: title),
    );
  }

  @override
  State<CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<CityPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<IndonesianCity> _allCities = IndonesianCitiesService.fallbackCities;
  List<IndonesianCity> _filteredCities = IndonesianCitiesService.fallbackCities;
  bool _isLoading = true;
  bool _isDetectingGps = false;
  String? _gpsMessage;

  @override
  void initState() {
    super.initState();
    _loadCityData();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadCityData() async {
    final cities = await IndonesianCitiesService.loadCities();
    if (mounted) {
      setState(() {
        _allCities = cities;
        _filteredCities = IndonesianCitiesService.searchCities(
          _searchController.text,
          customCities: cities,
        );
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    setState(() {
      _filteredCities = IndonesianCitiesService.searchCities(
        query,
        customCities: _allCities,
      );
    });
  }

  Future<void> _detectFromGps() async {
    setState(() {
      _isDetectingGps = true;
      _gpsMessage = null;
    });

    try {
      final controller = context.read<NearPaceController>();
      final locService = controller.locationService;

      GeoPointLite? position;
      if (locService != null) {
        final serviceEnabled = await locService.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (mounted) {
            setState(() {
              _gpsMessage = 'Location services are disabled. Enable GPS or select a city manually.';
            });
          }
          return;
        }

        var permission = await locService.checkPermission();
        if (permission == LocationPermissionStatus.notRequested ||
            permission == LocationPermissionStatus.denied) {
          permission = await locService.requestPermission();
        }
        if (permission != LocationPermissionStatus.granted) {
          if (mounted) {
            setState(() {
              _gpsMessage = permission == LocationPermissionStatus.deniedForever
                  ? 'Location permission is permanently denied. Select a city manually or enable GPS in Settings.'
                  : 'Location permission is required for GPS city detection.';
            });
          }
          return;
        }

        position = await locService.getLastKnownPosition();
        if (position == null) {
          // Listen to first stream point
          try {
            position = await locService.positionStream().first.timeout(
              const Duration(seconds: 4),
            );
          } catch (_) {}
        }
      }

      if (position != null) {
        final nearest = IndonesianCitiesService.findNearestCity(
          position.latitude,
          position.longitude,
          customCities: _allCities,
        );
        if (mounted) {
          Navigator.of(context).pop(nearest.name);
        }
      } else {
        if (mounted) {
          setState(() {
            _gpsMessage = 'Unable to get GPS fix. Please select manually.';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _gpsMessage = 'GPS detection failed. Please select manually.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDetectingGps = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(NearPaceSpacing.radiusLg),
        ),
        border: Border(
          top: BorderSide(color: colors.border),
          left: BorderSide(color: colors.border),
          right: BorderSide(color: colors.border),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: NearPaceSpacing.sm),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NearPaceSpacing.md,
                NearPaceSpacing.sm,
                NearPaceSpacing.md,
                NearPaceSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.title, style: textTheme.titleMedium),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: colors.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Detect from GPS Button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NearPaceSpacing.md,
              ),
              child: NearPaceCard(
                onTap: _isDetectingGps ? null : _detectFromGps,
                padding: const EdgeInsets.all(NearPaceSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.deepGreenSurface,
                        borderRadius: BorderRadius.circular(
                          NearPaceSpacing.radiusSm,
                        ),
                      ),
                      child: _isDetectingGps
                          ? Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.accent,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.my_location_rounded,
                              size: 18,
                              color: colors.accent,
                            ),
                    ),
                    const SizedBox(width: NearPaceSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detect from GPS',
                            style: textTheme.titleSmall?.copyWith(
                              color: colors.accentText,
                            ),
                          ),
                          Text(
                            'Matches nearest Indonesian city via GPS coordinate',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.textMuted,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),

            if (_gpsMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  NearPaceSpacing.md,
                  NearPaceSpacing.xs,
                  NearPaceSpacing.md,
                  0,
                ),
                child: Text(
                  _gpsMessage!,
                  style: textTheme.bodySmall?.copyWith(color: colors.warning),
                ),
              ),

            const SizedBox(height: NearPaceSpacing.xs),

            // Search Box
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NearPaceSpacing.md,
                vertical: NearPaceSpacing.xs,
              ),
              child: TextField(
                controller: _searchController,
                style: textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search city or province...',
                  hintStyle: textTheme.bodyMedium?.copyWith(
                    color: colors.textMuted,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: colors.textMuted,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: colors.surfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: NearPaceSpacing.sm,
                    vertical: NearPaceSpacing.xs,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      NearPaceSpacing.radiusSm,
                    ),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      NearPaceSpacing.radiusSm,
                    ),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      NearPaceSpacing.radiusSm,
                    ),
                    borderSide: BorderSide(color: colors.accent),
                  ),
                ),
              ),
            ),

            // City List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: colors.accent),
                    )
                  : _filteredCities.isEmpty
                  ? Center(
                      child: Text(
                        'No Indonesian cities matching "${_searchController.text}"',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: NearPaceSpacing.md,
                        vertical: NearPaceSpacing.xs,
                      ),
                      itemCount: _filteredCities.length,
                      separatorBuilder: (context, index) =>
                          Divider(color: colors.border, height: 1),
                      itemBuilder: (context, index) {
                        final city = _filteredCities[index];
                        final isSelected =
                            widget.currentCity != null &&
                            widget.currentCity!.trim().toLowerCase() ==
                                city.name.trim().toLowerCase();

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: NearPaceSpacing.xs,
                            vertical: 2,
                          ),
                          title: Text(
                            city.name,
                            style: textTheme.bodyLarge?.copyWith(
                              color: isSelected
                                  ? colors.accentText
                                  : colors.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            city.province,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: colors.accent,
                                  size: 20,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(city.name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
