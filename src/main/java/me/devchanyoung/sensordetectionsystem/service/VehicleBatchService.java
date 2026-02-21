package me.devchanyoung.sensordetectionsystem.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import me.devchanyoung.sensordetectionsystem.domain.DailyVehicleStats;
import me.devchanyoung.sensordetectionsystem.domain.HourlyVehicleStats;
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
            DailyVehicleStats dailyStats = DailyVehicleStats.createStats(
                    stat.getVehicleId(),
                    LocalDate.now(),
                    stat.getAvgSpeed(),
                    stat.getMaxSpeed()
            );
            dailyVehicleStatsRepository.save(dailyStats);
            log.info("✅ 일일 정산 완료 - 차량: {}, 평균 속도: {}, 최고 속도: {}",
                    stat.getVehicleId(), stat.getAvgSpeed(), stat.getMaxSpeed());
        }
    }
}