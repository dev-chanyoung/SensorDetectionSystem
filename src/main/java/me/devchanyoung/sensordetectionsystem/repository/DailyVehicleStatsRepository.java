package me.devchanyoung.sensordetectionsystem.repository;

import me.devchanyoung.sensordetectionsystem.domain.DailyVehicleStats;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface DailyVehicleStatsRepository extends JpaRepository<DailyVehicleStats, Long> {
    List<DailyVehicleStats> findAllByVehicleIdOrderByRecordDateDesc(String vehicleId);

    Optional<DailyVehicleStats> findByVehicleIdAndRecordDate(String vehicleId, LocalDate recordDate);
}
