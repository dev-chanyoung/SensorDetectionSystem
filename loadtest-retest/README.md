# loadtest-retest: 부하테스트 재검증 도구와 요약 데이터

2026-10-14~15에 2월 부하테스트를 다시 검증할 때 쓴 스크립트와 요약 결과입니다. 해석과 결론은 [부하테스트 재현](../docs/부하테스트_재현.md), 실험별 요약은 [실험 이력과 회고](../docs/실험_이력과_회고.md)에 있습니다.

> 이 스크립트는 제 Windows 노트북 한 대에서만 실행해 봤습니다. 다른 환경에서의 동작은 확인하지 않았습니다.

## 구성
| 위치 | 내용 |
|---|---|
| `scripts/run-case.ps1` | 한 조건을 실행: 앱 jar 기동 → DB·큐·Redis 초기화 → (워밍업) → JMeter 부하 → 모니터 기록 → 앱 종료 → `analyze.py` |
| `scripts/cli-queue.ps1` | 조건 큐: CLI 부하, 식을 때까지 대기, 반복, 순서 회전, 실행 결과 CSV 기록. `-Phase 0~9`로 실험 묶음 선택, `-CpuLog`로 프로세스별 CPU 기록 |
| `scripts/gui-matrix.ps1` | JMeter GUI(리스너 켬) 실험: 창 앞에 둠 / 최소화. 시작 버튼은 직접 누름 |
| `scripts/measure-cw.ps1` | 낮은 부하에서 요청 평균·커넥션 획득 대기·사용 시간 측정 (C/W 계산용) |
| `scripts/run-home.ps1`, `run-matrix.ps1`, `run-all.ps1`, `run-extra.ps1` | 위 스크립트를 이어서 실행하는 무인 실행 묶음 (실험 당시 사용한 순서 그대로) |
| `scripts/gui-queue.ps1` | JMeter GUI Start/종료 자동화 시도. 불안정해서 수동 방식으로 대체했습니다(참고용) |
| `scripts/analyze.py`, `p95-all.py` | 실행 결과 요약, 전체 결과의 p95 계산 |
| `scripts/plan.jmx`, `plan-gui.jmx` | CLI용 / GUI와 같은 리스너를 가진 JMeter 시나리오 (`POST /api/log`) |
| `data/` | 실행당 한 줄 요약 CSV: `cli-queue-results*.csv`, `gui-matrix-results.csv`, `cw-results.csv`, `p95-all.csv` |

원본 결과 폴더(`results/`, 실행당 JMeter 결과 파일과 CPU 기록)와 `jars/`는 용량이 커서 저장소에 포함하지 않았습니다. 문서의 수치는 `data/`의 CSV와 원본 결과 파일에서 계산했습니다.

## 준비물
- Windows, PowerShell 5.1, JDK 17, Apache JMeter 5.6.x, PostgreSQL, Docker (컨테이너 `safecar-redis`, `safecar-rabbitmq`)
- 환경변수 `JMETER_HOME`(JMeter 폴더), 필요하면 `JAVA_HOME`
- PostgreSQL에 측정용 DB `safecar_retest` 생성. 스크립트는 `psql -U postgres`로 접속하므로 비밀번호는 `PGPASSWORD` 또는 `pgpass`로 제공합니다. **스크립트는 실행 때마다 이 DB를 비웁니다. 운영·원본 DB 이름을 쓰지 마세요.**
- 빌드한 jar를 `scripts/jars/`에 둡니다 (`./gradlew bootJar -x test` 후 이름 변경):

| 파일 이름 | 커밋 | 설명 |
|---|---|---|
| `feb26.jar` | `4d30bd0` | 2/26 마지막 커밋 (`@Async` + Spring Event, pool 30, show-sql 켬) |
| `c-fae13e0.jar` | `fae13e0` | 2/27 (`@Async`, pool 17, Tomcat 7, accept 1000, show-sql 끔). 문서의 "동기" 빌드 |
| `c-c3bfdee.jar` | `c3bfdee` | RabbitMQ + Batch. 문서의 "MQ" 빌드 |

## 실행 예
```powershell
cd loadtest-retest/scripts
.\cli-queue.ps1 -Phase 0 -Reps 1                 # 스모크 테스트
.\cli-queue.ps1 -Phase 8 -Reps 3 -Tag fac        # 2x2x2 (스레드 x 풀 x accept, 8000명)
.\cli-queue.ps1 -Phase 9 -Reps 5 -Tag sql        # show-sql 끔/켬
.\cli-queue.ps1 -Phase 7 -Reps 2 -Tag sat -DryRun # 실행 없이 조건만 출력
python .\p95-all.py                               # results\ 전체의 p95 (p95-all.csv)
```
긴 측정은 숨김 창 + 출력 리다이렉트로 실행하세요. 콘솔 창을 최소화하면 에러율이 올라갔습니다(문서 14-9). 전원을 연결하고 절전을 막은 상태에서 측정합니다(스크립트가 절전 방지를 겁니다).

## 주의
- 한글이 들어 있는 `.ps1`은 UTF-8 BOM이 필요합니다. `.gitattributes`로 변환되지 않게 해 두었습니다.
- 스크립트가 만드는 `results/`, `logs/`, `*.log`, 결과 CSV는 `.gitignore`에 제외되어 있습니다.
- 해석과 한계(한 노트북, 부하 생성기와 서버 공존, 조건당 2~5회)는 [문서](../docs/부하테스트_재현.md)를 먼저 읽으세요.
