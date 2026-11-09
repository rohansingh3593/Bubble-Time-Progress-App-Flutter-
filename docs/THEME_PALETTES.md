# Dashboard theme palettes

The theme picker currently includes 12 color palettes. The colors below are the
values configured in `lib/constants/dashboard_themes.dart`; hex values are
shown without Flutter's `0xFF` alpha prefix.

## Light palette colors

| Palette | Primary | Secondary | Accent | Background | Surface | Card tint | Text | Muted text |
|---|---|---|---|---|---|---|---|---|
| Forest Glow | `#3E5A3F` | `#6B7F67` | `#607D58` | `#F4F6F0` | `#FFFFFF` | `#E5EBDD` | `#17251C` | `#4B5D4C` |
| Emerald Grey | `#047857` | `#10B981` | `#A7F3D0` | `#F3F7F5` | `#FFFFFF` | `#E7F4EF` | `#111827` | `#4B5F55` |
| Ocean Teal | `#2E6F73` | `#7FB3B8` | `#C6601F` | `#F3F8F7` | `#FFFFFF` | `#E2EFED` | `#142325` | `#426568` |
| Royal Focus | `#2563EB` | `#38BDF8` | `#F59E0B` | `#EFF6FF` | `#FFFFFF` | `#DBEAFE` | `#111827` | `#31586A` |
| Purple Haze | `#5A3B8C` | `#8B7CC7` | `#7B61B5` | `#F7F5FB` | `#FFFFFF` | `#ECE8F5` | `#201535` | `#5C526D` |
| Rose Blush | `#7A2E6F` | `#D6598F` | `#FF6B6B` | `#FFF5F4` | `#FFFFFF` | `#F8E4E2` | `#32172F` | `#6A4B61` |
| Sunset Orange | `#EA580C` | `#FB923C` | `#FACC15` | `#FFF7ED` | `#FFFFFF` | `#FFEDD5` | `#2D1B10` | `#6D4C41` |
| Minimal Cream | `#92400E` | `#D97706` | `#FBBF24` | `#FFFBEB` | `#FFFFFF` | `#FEF3C7` | `#2D241A` | `#756B5D` |
| Arctic Blue | `#334155` | `#64748B` | `#EC4899` | `#F1F5F9` | `#FFFFFF` | `#E2E8F0` | `#121212` | `#475569` |
| Olive Luxe | `#3E5A3F` | `#738A70` | `#9A6A35` | `#F7F4EC` | `#FFFFFF` | `#ECE7D8` | `#1B241B` | `#53604E` |
| Mocha Earth | `#6B4A2E` | `#8B6242` | `#9A6131` | `#FAF6F1` | `#FFFFFF` | `#EDE3D8` | `#281B13` | `#5D4A3A` |
| Midnight Navy | `#2563EB` | `#38BDF8` | `#22C55E` | `#0F172A` | `#1E293B` | `#27364B` | `#F8FAFC` | `#CBD5E1` |

## Status colors

These are configured per palette and are used for semantic success, warning,
and danger states.

| Palette | Success | Warning | Danger |
|---|---|---|---|
| Forest Glow | `#2E7D32` | `#986600` | `#B3261E` |
| Emerald Grey | `#22C55E` | `#F59E0B` | `#EF4444` |
| Ocean Teal | `#2E7D5B` | `#986000` | `#B3261E` |
| Royal Focus | `#22C55E` | `#F59E0B` | `#EF4444` |
| Purple Haze | `#2E7D5B` | `#A66300` | `#B3261E` |
| Rose Blush | `#2E7D5B` | `#986000` | `#B3261E` |
| Sunset Orange | `#2E7D5B` | `#986000` | `#B3261E` |
| Minimal Cream | `#22C55E` | `#D97706` | `#EF4444` |
| Arctic Blue | `#2E7D5B` | `#986000` | `#B3261E` |
| Olive Luxe | `#2E7D32` | `#986000` | `#B3261E` |
| Mocha Earth | `#2E7D5B` | `#986000` | `#B3261E` |
| Midnight Navy | `#22C55E` | `#F59E0B` | `#EF4444` |

## Dark mode

These palettes define explicit dark-mode background, surface, elevated-surface,
text, and muted-text colors:

| Palette | Background | Surface | Elevated surface | Text | Muted text |
|---|---|---|---|---|---|
| Forest Glow | `#0F1F17` | `#1E3A2E` | `#3E5A3F` | `#C7C8B8` | `#AEB9A6` |
| Purple Haze | `#0E0B1D` | `#2A1E4D` | `#3A3A52` | `#C9C2E3` | `#B8AED7` |
| Rose Blush | `#1A0F2E` | `#3B1B4F` | `#7A2E6F` | `#F4D7D4` | `#E6A6C3` |
| Arctic Blue | `#121212` | `#1F2937` | `#334155` | `#F1F5F9` | `#64748B` |
| Ocean Teal | `#0A0F14` | `#0F3D3E` | `#2E6F73` | `#EADCC8` | `#7FB3B8` |
| Olive Luxe | `#0B0F0D` | `#1F2A1F` | `#3E5A3F` | `#D9C7A3` | `#B8C6B2` |
| Mocha Earth | `#1A120E` | `#3A2418` | `#6B4A2E` | `#D5C4AE` | `#B89B7C` |
| Sunset Orange | `#1F120C` | `#3A1D12` | `#7C2D12` | `#FFF7ED` | `#FDBA74` |
| Midnight Navy | `#0F172A` | `#1E293B` | `#27364B` | `#F8FAFC` | `#CBD5E1` |

Emerald Grey, Royal Focus, and Minimal Cream do not define palette-specific
dark colors. In dark mode, the app derives their surfaces and text colors by
tinting the palette colors at runtime; dark-mode primary and secondary colors
are also lightened by the theme resolver. Midnight Navy is already configured
with dark colors as its base palette and has a dedicated dark-mode rendering
path.

## Palette inventory

1. Forest Glow
2. Emerald Grey
3. Ocean Teal
4. Royal Focus
5. Purple Haze
6. Rose Blush
7. Sunset Orange
8. Minimal Cream
9. Arctic Blue
10. Olive Luxe
11. Mocha Earth
12. Midnight Navy

The names and values in this document follow the selectable palette list in
`dashboardThemePickerPalettes`. Legacy palette names are migrated to a retained
palette and are not separate choices in the current picker.

## Dashboard scenic wallpapers

The Today dashboard uses the selected palette to choose its background image.
The palette preference remains persisted by the existing Hive theme setting.
Wallpaper files are registered from `assets/wallpapers/`.
Images fill the available content area with `BoxFit.cover`; changing palettes
fades to the new image unless reduced motion is enabled. A failed image load
falls back to the palette's existing background color. The light and dark
surfaces are overlaid with a subtle theme-aware scrim.

| Active palette | Approved wallpaper asset |
|---|---|
| Forest Glow | `19_Forest_Glow_Version_2.png` |
| Emerald Grey | `02_Emerald_Grey.png` |
| Ocean Teal | `23_Ocean_Teal.png` |
| Royal Focus | `05_Royal_Focus_Wider_Coastline.png` |
| Purple Haze | `18_Purple_Haze_Version_2.png` |
| Rose Blush | `21_Rose_Blush.png` |
| Sunset Orange | `14_Sunset_Orange_Version_2.png` |
| Minimal Cream | `06_Minimal_Cream.png` |
| Arctic Blue | `22_Arctic_Blue.png` |
| Olive Luxe | `25_Olive_Luxe.png` |
| Mocha Earth | `26_Mocha_Earth.png` |
| Midnight Navy | `13_Midnight_Navy_Version_2.png` |

These source images include palette labels and color swatches over the scenery.
The originals are preserved; the embedded graphics may remain visible in the
dashboard and are not modified by the app.
