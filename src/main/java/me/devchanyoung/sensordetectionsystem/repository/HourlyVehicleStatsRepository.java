package me.devchanyoung.sensordetectionsystem.repository;

import me.devchanyoung.sensordetectionsystem.domain.HourlyVehicleStats;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.List;

public interface HourlyVehicleStatsRepository extends JpaRepository<HourlyVehicleStats, Long> {

    List<HourlyVehicleStats> findAllByRecordHourGreaterThanEqualAndRecordHourLessThan(LocalDateTime start, LocalDateTime end);
}
