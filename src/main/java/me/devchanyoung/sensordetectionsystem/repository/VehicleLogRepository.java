package me.devchanyoung.sensordetectionsystem.repository;

import me.devchanyoung.sensordetectionsystem.domain.VehicleLog;
import org.springframework.data.jpa.repository.JpaRepository;

public interface VehicleLogRepository extends JpaRepository<VehicleLog, Long> {
}
