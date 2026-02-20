package me.devchanyoung.sensordetectionsystem.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import me.devchanyoung.sensordetectionsystem.domain.DaliyVehicleStats;
import me.devchanyoung.sensordetectionsystem.repository.DailyVehicleStatsRepository;
import me.devchanyoung.sensordetectionsystem.repository.VehicleLogRepository;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class VehicleBatchService {

    private final VehicleLogRepository vehicleLogRepository;
    private final DailyVehicleStatsRepository dailyVehicleStatsRepository;

    // @Scheduled(cron = "0 0 0 * * *") // 실제 배포 용
    @Scheduled(cron = "0 * * * * *") // 테스트 용
    @Transactional
    public void calculateDailyStats(){
        log.info("[Batch] 일일 데이터 정상 배치를 시작합니다.");

        LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
        LocalDateTime endOfDay = startOfDay.plusDays(1);

        List<VehicleLogRepository.DailyStatProjection> statsList =
                vehicleLogRepository.findDailyStats(startOfDay, endOfDay);

        for (VehicleLogRepository.DailyStatProjection stat : statsList) {
            DaliyVehicleStats daliStats = DaliyVehicleStats.createStats(
                    stat.getVehicleId(),
                    LocalDate.now(),
                    stat.getAvgSpeed(),
                    stat.getMaxSpeed()
            );
            dailyVehicleStatsRepository.save(daliStats);
            log.info("정산 완료 - 차량: {}, 평균 속도: {}, 최고 속도: {}",
                    stat.getVehicleId(), stat.getAvgSpeed(), stat.getMaxSpeed());
        }

        log.info("[Batch] 일일 데이터 정상 배치가 완료되었습니다.");
    }
}
