package me.devchanyoung.sensordetectionsystem.repository;


import me.devchanyoung.sensordetectionsystem.domain.Alert;
import me.devchanyoung.sensordetectionsystem.domain.AlertType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;

public interface AlertRepository extends JpaRepository<Alert, Long> {

    @Query("SELECT COUNT(a) FROM Alert a WHERE a.vehicleId = :vehicleId AND a.alertType = :type AND a.createdAt >= :start AND a.createdAt < :end")
    long countByVehicleIdAndTypeAndDate(
            @Param("vehicleId") String vehicleId,
            @Param("type") AlertType type,
            @Param("start") LocalDateTime start,
            @Param("end") LocalDateTime end
    );
}
