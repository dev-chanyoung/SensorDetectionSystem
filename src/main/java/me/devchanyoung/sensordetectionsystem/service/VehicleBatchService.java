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
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class VehicleBatchService {

    private final VehicleLogRepository vehicleLogRepository;
    private final HourlyVehicleStatsRepository hourlyVehicleStatsRepository;
    private final DailyVehicleStatsRepository dailyVehicleStatsRepository;
    private final AlertRepository alertRepository;


    // 1. 중간 집계
    // @Scheduled(cron = "0 0 * * * *") // 실제 배포 용: 매시간 정각
    @Scheduled(cron = "0 * * * * *")    // 테스트 용: 매분 0초
    @Transactional
    public void calculateHourlyStats(){
        LocalDateTime now = LocalDateTime.now().truncatedTo(ChronoUnit.MINUTES);
        LocalDateTime startOfTarget = now.minusMinutes(1);

        log.info("📊 [Batch] 중간 집계 배치를 시작합니다. 대상 시간: {} ~ {}", startOfTarget, now);

        List<VehicleLogRepository.HourlyStatProjection> statsList =
                vehicleLogRepository.findHourlyStats(startOfTarget, now);

        for (VehicleLogRepository.HourlyStatProjection stat : statsList) {
            HourlyVehicleStats hourlyStats = HourlyVehicleStats.create(
                    stat.getVehicleId(),
                    startOfTarget,
                    stat.getAvgSpeed(),
                    stat.getMaxSpeed(),
                    stat.getDataCount()
            );
            hourlyVehicleStatsRepository.save(hourlyStats);
            log.info("✅ 중간 집계 완료 - 차량: {}, 평균 속도: {}, 데이터 건수: {}",
                    stat.getVehicleId(), stat.getAvgSpeed(), stat.getDataCount());
        }
    }

    // 2. 최종 일일 정산 (Daily Settlement)
    // @Scheduled(cron = "0 * * * * *") // 실제 배포 용: 매일 밤 12시 정각
    @Scheduled(cron = "0 0 * * * *")    // 테스트용: 매 시간 정각
    @Transactional
    public void calculateDailyStats() {
        log.info("📊 [Batch] 일일 데이터 정산 배치를 시작합니다.");

        LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
        LocalDateTime endOfDay = startOfDay.plusDays(1);

        List<VehicleLogRepository.HourlyStatProjection> statsList =
                vehicleLogRepository.findHourlyStats(startOfDay, endOfDay);

        for (VehicleLogRepository.HourlyStatProjection stat : statsList) {

            // 1. 이상 탐지 발생 횟수 조회
            long speedingCount = alertRepository.countByVehicleIdAndTypeDate(
                    stat.getVehicleId(), AlertType.SPEEDING, startOfDay, endOfDay);
            long suddenAccelCount = alertRepository.countByVehicleIdAndTypeDate(
                    stat.getVehicleId(), AlertType.SUDDEN_ACCEL, startOfDay, endOfDay);

            // 2. 안전 점수 계산(알고리즘: 100점 기본, 과속 1회당 -5점, 금가속 1회당 -10점)
            int penalty = (int) (speedingCount * 5) + (int) (suddenAccelCount * 10);
            int safetyScore = Math.max(100-penalty, 0); // 최소 점수 0점

            // 객체 생성 및 저장
            DailyVehicleStats dailyStats = DailyVehicleStats.createStats(
                    stat.getVehicleId(),
                    LocalDate.now(),
                    stat.getAvgSpeed(),
                    stat.getMaxSpeed(),
                    safetyScore
            );

            dailyVehicleStatsRepository.save(dailyStats);
            log.info("✅ 일일 정산 완료 - 차량: {}, 평균 속도: {}, 최고 속도: {}, 과속: {}회, 급가속: {}회, 최종 안전 점수: {}점",
                    stat.getVehicleId(), stat.getAvgSpeed(), stat.getMaxSpeed(), speedingCount, suddenAccelCount, safetyScore);
        }
    }
}