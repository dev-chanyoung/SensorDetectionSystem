package me.devchanyoung.sensordetectionsystem.service;

import me.devchanyoung.sensordetectionsystem.domain.AlertType;
import me.devchanyoung.sensordetectionsystem.domain.DailyVehicleStats;
import me.devchanyoung.sensordetectionsystem.domain.HourlyVehicleStats;
import me.devchanyoung.sensordetectionsystem.repository.AlertRepository;
import me.devchanyoung.sensordetectionsystem.repository.DailyVehicleStatsRepository;
import me.devchanyoung.sensordetectionsystem.repository.HourlyVehicleStatsRepository;
import me.devchanyoung.sensordetectionsystem.repository.VehicleLogRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class VehicleBatchServiceTest {

    private static final LocalDate DAY = LocalDate.of(2026, 2, 26);

    @InjectMocks
    private VehicleBatchService batchService;

    @Mock
    private VehicleLogRepository vehicleLogRepository;

    @Mock
    private HourlyVehicleStatsRepository hourlyVehicleStatsRepository;

    @Mock
    private DailyVehicleStatsRepository dailyVehicleStatsRepository;

    @Mock
    private AlertRepository alertRepository;

    private void givenHourlyRows(HourlyVehicleStats... rows) {
        given(hourlyVehicleStatsRepository.findAllByRecordHourGreaterThanEqualAndRecordHourLessThan(
                DAY.atStartOfDay(), DAY.plusDays(1).atStartOfDay())).willReturn(List.of(rows));
    }

    @Test
    @DisplayName("일일 정산은 원본 로그가 아니라 중간 집계 테이블을 읽고, 평균은 건수로 가중한다")
    void settleDailyStats_readsHourlyStats_withWeightedAverage() {
        givenHourlyRows(
                HourlyVehicleStats.create("Car-1", DAY.atTime(9, 0), 100.0, 120.0, 1),
                HourlyVehicleStats.create("Car-1", DAY.atTime(10, 0), 50.0, 90.0, 3));
        given(alertRepository.countByVehicleIdAndTypeAndDate(eq("Car-1"), eq(AlertType.SPEEDING), any(), any())).willReturn(2L);
        given(alertRepository.countByVehicleIdAndTypeAndDate(eq("Car-1"), eq(AlertType.SUDDEN_ACCEL), any(), any())).willReturn(1L);
        given(dailyVehicleStatsRepository.findByVehicleIdAndRecordDate("Car-1", DAY)).willReturn(Optional.empty());

        batchService.settleDailyStats(DAY);

        ArgumentCaptor<DailyVehicleStats> saved = ArgumentCaptor.forClass(DailyVehicleStats.class);
        verify(dailyVehicleStatsRepository, times(1)).save(saved.capture());
        assertThat(saved.getValue().getRecordDate()).isEqualTo(DAY);
        assertThat(saved.getValue().getAvgSpeed()).isEqualTo(62.5);   // (100*1 + 50*3) / 4
        assertThat(saved.getValue().getMaxSpeed()).isEqualTo(120.0);
        assertThat(saved.getValue().getSafetyScore()).isEqualTo(80);  // 100 - 2*5 - 1*10
        verify(vehicleLogRepository, never()).findHourlyStats(any(), any());
    }

    @Test
    @DisplayName("같은 차량·날짜를 다시 정산하면 새 행을 만들지 않고 기존 행을 갱신한다")
    void settleDailyStats_existingRow_isUpdatedNotDuplicated() {
        givenHourlyRows(HourlyVehicleStats.create("Car-1", DAY.atTime(9, 0), 80.0, 100.0, 5));
        DailyVehicleStats existing = DailyVehicleStats.createStats("Car-1", DAY, 10.0, 10.0, 100);
        given(dailyVehicleStatsRepository.findByVehicleIdAndRecordDate("Car-1", DAY)).willReturn(Optional.of(existing));

        batchService.settleDailyStats(DAY);

        verify(dailyVehicleStatsRepository, times(1)).save(existing);
        assertThat(existing.getAvgSpeed()).isEqualTo(80.0);
        assertThat(existing.getMaxSpeed()).isEqualTo(100.0);
    }

    @Test
    @DisplayName("감점이 100점을 넘으면 안전 점수는 0점이다")
    void settleDailyStats_scoreIsFlooredAtZero() {
        givenHourlyRows(HourlyVehicleStats.create("Car-1", DAY.atTime(9, 0), 80.0, 100.0, 5));
        given(alertRepository.countByVehicleIdAndTypeAndDate(eq("Car-1"), eq(AlertType.SPEEDING), any(), any())).willReturn(30L);
        given(dailyVehicleStatsRepository.findByVehicleIdAndRecordDate("Car-1", DAY)).willReturn(Optional.empty());

        batchService.settleDailyStats(DAY);

        ArgumentCaptor<DailyVehicleStats> saved = ArgumentCaptor.forClass(DailyVehicleStats.class);
        verify(dailyVehicleStatsRepository).save(saved.capture());
        assertThat(saved.getValue().getSafetyScore()).isZero();
    }

    @Test
    @DisplayName("중간 집계는 원본 로그를 구간 단위로 집계해 요약 테이블에 적재한다")
    void aggregateHourlyStats_savesSummaryPerVehicle() {
        LocalDateTime start = DAY.atTime(9, 0);
        LocalDateTime end = DAY.atTime(10, 0);
        VehicleLogRepository.HourlyStatProjection projection = new VehicleLogRepository.HourlyStatProjection() {
            public String getVehicleId() { return "Car-1"; }
            public double getMaxSpeed() { return 120.0; }
            public double getAvgSpeed() { return 90.0; }
            public long getDataCount() { return 7; }
        };
        given(vehicleLogRepository.findHourlyStats(start, end)).willReturn(List.of(projection));

        batchService.aggregateHourlyStats(start, end);

        ArgumentCaptor<HourlyVehicleStats> saved = ArgumentCaptor.forClass(HourlyVehicleStats.class);
        verify(hourlyVehicleStatsRepository).save(saved.capture());
        assertThat(saved.getValue().getVehicleId()).isEqualTo("Car-1");
        assertThat(saved.getValue().getRecordHour()).isEqualTo(start);
        assertThat(saved.getValue().getDataCount()).isEqualTo(7);
    }
}
