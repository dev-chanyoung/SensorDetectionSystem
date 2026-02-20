package me.devchanyoung.sensordetectionsystem.repository;

import me.devchanyoung.sensordetectionsystem.domain.VehicleLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;

public interface VehicleLogRepository extends JpaRepository<VehicleLog, Long> {

    @Query("select v.vehicleId AS vehicleId, AVG(v.speed) AS avgSpeed, MAX(v.speed) AS maxSpeed " +
            "from VehicleLog v " +
            "where v.createdAt >= :start AND v.createdAt < :end " +
            "group by v.vehicleId")
    List<DailyStatProjection> findDailyStats(@Param("start")LocalDateTime start, @Param("end") LocalDateTime end);


    interface DailyStatProjection {
        String getVehicleId();
        double getMaxSpeed();
        double getAvgSpeed();
    }
}

