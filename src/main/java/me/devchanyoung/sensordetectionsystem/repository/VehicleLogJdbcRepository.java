package me.devchanyoung.sensordetectionsystem.repository;


import lombok.RequiredArgsConstructor;
import me.devchanyoung.sensordetectionsystem.domain.VehicleLog;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.PreparedStatement;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.List;

@Repository
@RequiredArgsConstructor
public class VehicleLogJdbcRepository {

    private final JdbcTemplate jdbcTemplate;

    // Bulk Insert : 대용량 데이터 한번의 쿼리로 묶어서 DB 전송
    public void saveAllBulk(List<VehicleLog> logs) {
        // ID 제외하고 생성하는 쿼리
        String sql = "INSERT INTO vehicle_log (vehicle_id, speed, rpm, created_at) VALUES (?, ?, ?, ?)";

        // batchUpdate: 1000건씩 묶어서 DB에 전송 (네트워크 비용 획기적 감소)
        jdbcTemplate.batchUpdate(sql,
                logs,
                1000,
                (PreparedStatement ps, VehicleLog log) -> {
            ps.setString(1, log.getVehicleId());
            ps.setDouble(2, log.getSpeed());
            ps.setDouble(3, log.getRpm());
            ps.setTimestamp(4, Timestamp.valueOf(LocalDateTime.now()));
                });

    }
}
