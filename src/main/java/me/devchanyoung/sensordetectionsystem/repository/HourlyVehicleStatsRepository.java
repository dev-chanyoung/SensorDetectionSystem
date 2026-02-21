package me.devchanyoung.sensordetectionsystem.repository;

import me.devchanyoung.sensordetectionsystem.domain.HourlyVehicleStats;
import org.springframework.data.jpa.repository.JpaRepository;

public interface HourlyVehicleStatsRepository extends JpaRepository<HourlyVehicleStats, Long> {

}
