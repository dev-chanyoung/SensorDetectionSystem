package me.devchanyoung.sensordetectionsystem.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import me.devchanyoung.sensordetectionsystem.domain.AlertType;
import me.devchanyoung.sensordetectionsystem.domain.DailyVehicleStats;
import me.devchanyoung.sensordetectionsystem.domain.HourlyVehicleStats;
import me.devchanyoung.sensordetectionsystem.repository.AlertRepository;
import me.devchanyoung.sensordetectionsystem.repository.DailyVehicleStatsRepository;
import me.devchanyoung.sensordetectionsystem.repository.HourlyVehicleStatsRepository;
import me.devchanyoung.sensordetectionsystem.repository.VehicleLogRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 배치 주기와 집계 구간은 application.properties(batch.*)로 조정한다.
 * 기본값은 운영 기준(중간 집계 매시 정각, 일일 정산 매일 00:05)이고,
 * 기능 확인 때는 주기를 분·시간 단위로 줄여서 실행한다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class VehicleBatchService {

    private final VehicleLogRepository vehicleLogRepository;
    private final HourlyVehicleStatsRepository hourlyVehicleStatsRepository;
    private final DailyVehicleStatsRepository dailyVehicleStatsRepository;
    private final AlertRepository alertRepository;

    @Value("${batch.hourly-stats.window-minutes:60}")
    private long hourlyWindowMinutes;

    @Value("${batch.daily-stats.target-days-ago:1}")
    private long dailyTargetDaysAgo;

    // 1. 중간 집계: 원본 로그를 구간(window) 단위로 미리 계산해 HourlyVehicleStats에 적재
    @Scheduled(cron = "${batch.hourly-stats.cron:0 0 * * * *}")
    @Transactional
    public void calculateHourlyStats() {
        LocalDateTime end = LocalDateTime.now().truncatedTo(ChronoUnit.MINUTES);
        aggregateHourlyStats(end.minusMinutes(hourlyWindowMinutes), end);
    }

    public void aggregateHourlyStats(LocalDateTime start, LocalDateTime end) {
        log.info("📊 [Batch] 중간 집계 배치를 시작합니다. 대상 시간: {} ~ {}", start, end);

        List<VehicleLogRepository.HourlyStatProjection> statsList =
                vehicleLogRepository.findHourlyStats(start, end);

        for (VehicleLogRepository.HourlyStatProjection stat : statsList) {
            hourlyVehicleStatsRepository.save(HourlyVehicleStats.create(
                    stat.getVehicleId(),
                    start,
                    stat.getAvgSpeed(),
                    stat.getMaxSpeed(),
                    stat.getDataCount()
            ));
            log.info("✅ 중간 집계 완료 - 차량: {}, 평균 속도: {}, 데이터 건수: {}",
                    stat.getVehicleId(), stat.getAvgSpeed(), stat.getDataCount());
        }
    }

    // 2. 최종 일일 정산: 원본 로그가 아니라 중간 집계 테이블을 읽는다.
    // 00:00 정각에는 마지막 중간 집계(전날 23시 구간)가 아직 저장 중일 수 있어 00:05에 실행한다.
    @Scheduled(cron = "${batch.daily-stats.cron:0 5 0 * * *}")
    @Transactional
    public void calculateDailyStats() {
        settleDailyStats(LocalDate.now().minusDays(dailyTargetDaysAgo));
    }

    public void settleDailyStats(LocalDate targetDate) {
        log.info("📊 [Batch] 일일 데이터 정산 배치를 시작합니다. 대상 날짜: {}", targetDate);

        LocalDateTime startOfDay = targetDate.atStartOfDay();
        LocalDateTime endOfDay = startOfDay.plusDays(1);

        Map<String, List<HourlyVehicleStats>> byVehicle = hourlyVehicleStatsRepository
                .findAllByRecordHourGreaterThanEqualAndRecordHourLessThan(startOfDay, endOfDay)
                .stream()
                .collect(Collectors.groupingBy(HourlyVehicleStats::getVehicleId, LinkedHashMap::new, Collectors.toList()));

        for (Map.Entry<String, List<HourlyVehicleStats>> entry : byVehicle.entrySet()) {
            String vehicleId = entry.getKey();
            List<HourlyVehicleStats> rows = entry.getValue();

            // 1. 구간별 평균을 건수로 가중해 하루 평균을 구한다.
            long totalCount = rows.stream().mapToLong(HourlyVehicleStats::getDataCount).sum();
            double avgSpeed = totalCount == 0 ? 0
                    : rows.stream().mapToDouble(r -> r.getAvgSpeed() * r.getDataCount()).sum() / totalCount;
            double maxSpeed = rows.stream().mapToDouble(HourlyVehicleStats::getMaxSpeed).max().orElse(0);

            // 2. 이상 탐지 발생 횟수 조회
            long speedingCount = alertRepository.countByVehicleIdAndTypeAndDate(
                    vehicleId, AlertType.SPEEDING, startOfDay, endOfDay);
            long suddenAccelCount = alertRepository.countByVehicleIdAndTypeAndDate(
                    vehicleId, AlertType.SUDDEN_ACCEL, startOfDay, endOfDay);

            // 3. 안전 점수 계산(알고리즘: 100점 기본, 과속 1회당 -5점, 급가속 1회당 -10점)
            int penalty = (int) (speedingCount * 5) + (int) (suddenAccelCount * 10);
            int safetyScore = Math.max(100 - penalty, 0); // 최소 점수 0점

            // 4. 같은 차량·날짜를 다시 정산해도 행이 늘지 않도록 있으면 갱신한다.
            DailyVehicleStats dailyStats = dailyVehicleStatsRepository
                    .findByVehicleIdAndRecordDate(vehicleId, targetDate)
                    .map(existing -> {
                        existing.update(avgSpeed, maxSpeed, safetyScore);
                        return existing;
                    })
                    .orElseGet(() -> DailyVehicleStats.createStats(vehicleId, targetDate, avgSpeed, maxSpeed, safetyScore));
            dailyVehicleStatsRepository.save(dailyStats);

            log.info("✅ 일일 정산 완료 - 차량: {}, 평균 속도: {}, 최고 속도: {}, 과속: {}회, 급가속: {}회, 최종 안전 점수: {}점",
                    vehicleId, avgSpeed, maxSpeed, speedingCount, suddenAccelCount, safetyScore);
        }
    }
}
