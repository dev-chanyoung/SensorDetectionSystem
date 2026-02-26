package me.devchanyoung.sensordetectionsystem.repository;

import me.devchanyoung.sensordetectionsystem.domain.DailyVehicleStats;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface DailyVehicleStatsRepository extends JpaRepository<DailyVehicleStats, Long> {
    List<DailyVehicleStats> findAllByVehicleIdOrderByRecordDateDesc(String vehicleId);
}