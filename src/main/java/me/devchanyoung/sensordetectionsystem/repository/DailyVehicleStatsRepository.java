package me.devchanyoung.sensordetectionsystem.repository;

import me.devchanyoung.sensordetectionsystem.domain.DailyVehicleStats;
import org.springframework.data.jpa.repository.JpaRepository;

public interface DailyVehicleStatsRepository extends JpaRepository<DailyVehicleStats, Long> {

}