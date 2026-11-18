import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geomag/screens/anomaly_map_screen.dart';
import 'package:geomag/services/gridding_service.dart';
import 'package:geomag/services/qgis_export_service.dart';

void main() {
  const exportService = QgisExportService();

  group('ESRI ASCII Grid Export (.asc)', () {
    test('formatEsriAsciiGrid menghasilkan format header dan urutan baris utara-selatan yang benar', () {
      // 2 rows x 3 cols:
      // Row 0 (Y min / selatan): [1.0, 2.0, 3.0]
      // Row 1 (Y max / utara):   [4.0, 5.0, 6.0]
      final grid = Grid2D(
        xMin: 100.0,
        xMax: 120.0,
        yMin: 200.0,
        yMax: 210.0,
        dx: 10.0,
        dy: 10.0,
        nx: 3,
        ny: 2,
        xCoords: const [100.0, 110.0, 120.0],
        yCoords: const [200.0, 210.0],
        values: const [
          [1.0, 2.0, 3.0],
          [4.0, 5.0, 6.0],
        ],
      );

      final ascStr = exportService.formatEsriAsciiGrid(grid);
      final lines = ascStr.trim().split('\n').map((l) => l.trim()).toList();

      expect(lines.length, 8);
      expect(lines[0], 'ncols         3');
      expect(lines[1], 'nrows         2');
      expect(lines[2], 'xllcorner     100.000000');
      expect(lines[3], 'yllcorner     200.000000');
      expect(lines[4], 'cellsize      10.000000');
      expect(lines[5], 'NODATA_value  -9999');

      // Baris pertama raster di file harus baris paling utara (Row 1)
      expect(lines[6], '4.000 5.000 6.000');
      // Baris kedua raster di file adalah baris selatan (Row 0)
      expect(lines[7], '1.000 2.000 3.000');
    });

    test('formatEsriAsciiGrid menangani nilai NaN / Infinity dengan NODATA_value', () {
      final grid = Grid2D(
        xMin: 0.0,
        xMax: 5.0,
        yMin: 0.0,
        yMax: 5.0,
        dx: 5.0,
        dy: 5.0,
        nx: 2,
        ny: 2,
        xCoords: const [0.0, 5.0],
        yCoords: const [0.0, 5.0],
        values: [
          [double.nan, 12.5],
          [34.2, double.infinity],
        ],
      );

      final ascStr = exportService.formatEsriAsciiGrid(grid, nodataValue: -9999.0);
      final lines = ascStr.trim().split('\n').map((l) => l.trim()).toList();

      expect(lines[6], '34.200 -9999.0');
      expect(lines[7], '-9999.0 12.500');
    });
  });

  group('GeoJSON Stations Export (.geojson)', () {
    test('formatStationsGeoJson menghasilkan struktur FeatureCollection WGS-84 yang valid', () {
      final stations = [
        const MapStationMarker(
          stationId: 'ST-01',
          sequenceNumber: 1,
          x: 0.0,
          y: 0.0,
          latitude: -6.891234,
          longitude: 107.612345,
          totalFieldNt: 45050.25,
          diurnalCorrectionNt: 4.15,
          fIgrfNt: 44980.10,
          deltaTNt: 66.00,
          isAccepted: true,
          qualityFlag: 'ACCEPTED',
        ),
        const MapStationMarker(
          stationId: 'ST-02',
          sequenceNumber: 2,
          x: 10.0,
          y: 0.0,
          latitude: -6.892000,
          longitude: 107.613000,
          totalFieldNt: 45080.50,
          isAccepted: false,
          qualityFlag: 'REJECTED',
        ),
        // Stasiun tanpa koordinat GPS harus diabaikan
        const MapStationMarker(
          stationId: 'ST-NO-GPS',
          sequenceNumber: 3,
          x: 20.0,
          y: 0.0,
          totalFieldNt: 45000.0,
          isAccepted: true,
          qualityFlag: 'ACCEPTED',
        ),
      ];

      final geoJsonStr = exportService.formatStationsGeoJson(stations);
      final jsonMap = jsonDecode(geoJsonStr) as Map<String, dynamic>;

      expect(jsonMap['type'], 'FeatureCollection');
      final features = jsonMap['features'] as List<dynamic>;
      expect(features.length, 2);

      final f1 = features[0] as Map<String, dynamic>;
      expect(f1['type'], 'Feature');
      expect(f1['geometry']['type'], 'Point');
      expect(f1['geometry']['coordinates'], [107.612345, -6.891234]);
      expect(f1['properties']['station_id'], 'ST-01');
      expect(f1['properties']['delta_t_nt'], 66.00);
      expect(f1['properties']['is_accepted'], true);

      final f2 = features[1] as Map<String, dynamic>;
      expect(f2['properties']['station_id'], 'ST-02');
      expect(f2['properties']['diurnal_correction_nt'], isNull);
      expect(f2['properties']['is_accepted'], false);
    });
  });

  group('CSV Anomalies Export (.csv)', () {
    test('formatAnomaliesCsv menghasilkan baris CSV dengan kolom terformat rapi', () {
      final stations = [
        const MapStationMarker(
          stationId: 'ST-01',
          sequenceNumber: 1,
          x: 0.0,
          y: 0.0,
          latitude: -6.891234,
          longitude: 107.612345,
          totalFieldNt: 45050.25,
          diurnalCorrectionNt: 4.15,
          fIgrfNt: 44980.10,
          deltaTNt: 66.00,
          isAccepted: true,
          qualityFlag: 'ACCEPTED',
        ),
      ];

      final csvStr = exportService.formatAnomaliesCsv(stations);
      final lines = csvStr.trim().split('\n');

      expect(lines.length, 2);
      expect(
        lines[0],
        'station_id,sequence_number,latitude,longitude,local_x_m,local_y_m,total_field_nt,diurnal_correction_nt,f_igrf_nt,delta_t_nt,is_accepted,quality_flag',
      );
      expect(
        lines[1],
        'ST-01,1,-6.8912340,107.6123450,0.00,0.00,45050.25,4.15,44980.10,66.00,true,ACCEPTED',
      );
    });
  });

  group('File Writing Helpers', () {
    test('export files to temporary directory', () async {
      final tempDir = await Directory.systemTemp.createTemp('geomag_export_test');
      try {
        final ascPath = '${tempDir.path}/test_grid.asc';
        final geoJsonPath = '${tempDir.path}/test_stations.geojson';
        final csvPath = '${tempDir.path}/test_anomalies.csv';

        final grid = Grid2D(
          xMin: 0.0,
          xMax: 10.0,
          yMin: 0.0,
          yMax: 10.0,
          dx: 10.0,
          dy: 10.0,
          nx: 2,
          ny: 2,
          xCoords: const [0.0, 10.0],
          yCoords: const [0.0, 10.0],
          values: const [
            [1.0, 2.0],
            [3.0, 4.0],
          ],
        );

        final stations = [
          const MapStationMarker(
            stationId: 'ST-01',
            sequenceNumber: 1,
            x: 0.0,
            y: 0.0,
            latitude: -6.89,
            longitude: 107.61,
            totalFieldNt: 45000.0,
            isAccepted: true,
            qualityFlag: 'ACCEPTED',
          ),
        ];

        final ascFile = await exportService.exportAsciiGridToFile(
          grid: grid,
          filePath: ascPath,
        );
        expect(await ascFile.exists(), isTrue);

        final geoJsonFile = await exportService.exportGeoJsonToFile(
          stations: stations,
          filePath: geoJsonPath,
        );
        expect(await geoJsonFile.exists(), isTrue);

        final csvFile = await exportService.exportCsvToFile(
          stations: stations,
          filePath: csvPath,
        );
        expect(await csvFile.exists(), isTrue);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
