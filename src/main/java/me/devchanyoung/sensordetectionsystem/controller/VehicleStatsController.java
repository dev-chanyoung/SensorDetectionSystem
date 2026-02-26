package me.devchanyoung.sensordetectionsystem.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import me.devchanyoung.sensordetectionsystem.domain.DailyVehicleStats;
import me.devchanyoung.sensordetectionsystem.dto.DailyStatsResponse;
import me.devchanyoung.sensordetectionsystem.repository.DailyVehicleStatsRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.stream.Collectors;

@Tag(name = "Vehicle Stats API", description = "차량 통계 및 안전 점수 조회 API")
@RestController
@RequestMapping("/apt/stats")
@RequiredArgsConstructor
public class VehicleStatsController {

    private final DailyVehicleStatsRepository dailyVehicleStatsRepository;

    @Operation(summary = "차량별 일일 통계 조회", description = "특정 차량의 날짜별 운행 통계와 안전 점수를 최근 날짜순으로 출력")
    @GetMapping("/{vehicleId}")
    public ResponseEntity<List<DailyStatsResponse>> getDailyStats(@PathVariable String vehicleId) {
        List<DailyVehicleStats> statsList = dailyVehicleStatsRepository.findAllByVehicleIdOrderByRecordDateDesc(vehicleId);

        List<DailyStatsResponse> responses = statsList.stream()
                .map(DailyStatsResponse::from)
                .collect(Collectors.toList());

        return ResponseEntity.ok(responses);
    }
}
