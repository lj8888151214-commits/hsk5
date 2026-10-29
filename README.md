# 📚 HSK 5급 단어 퀴즈 웹 앱 (HSK 5 Quiz Web)
> **FastAPI 백엔드와 Flutter Web 기반의 반응형 HSK 5급 단어 학습 & 오답 복습 플랫폼 (PWA 지원)**

---

### 💡 1. 기획 의도 및 배경

| 항목 | 내용 |
| :--- | :--- |
| **효율적인 어휘 암기 트레이닝** | HSK 5급 필수 어휘(2,470단어)를 4지선다형 객관식 퀴즈 형태로 반복 학습하여 실전 어휘 적응력을 극대화합니다. |
| **능동적 취약점 보완 (오답노트)** | 풀이 중 틀린 단어는 브라우저 세션에 즉시 누적 기록되며, 오답만 모아 별도로 재응시할 수 있는 복습 모드를 제공합니다. |
| **무설치 크로스 플랫폼 (PWA)** | 복잡한 앱스토어 설치 과정 없이 모바일/PC 브라우저에서 즉시 실행되며, 모바일 홈 화면 추가 시 네이티브 앱과 동일한 UX를 지원합니다. |
| **Link** |https://hsk5-hsk5quizapp.vercel.app|


---

<section id="tech-stack">
  <h3>🛠 2. 사용 기술 (Tech Stack)</h3>

  <h4>Backend &amp; Database</h4>
  <p>
    <img src="https://img.shields.io/badge/Python_3.11-3776AB?style=flat-square&logo=python&logoColor=white" alt="Python 3.11" />
    <img src="https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white" alt="FastAPI" />
    <img src="https://img.shields.io/badge/Uvicorn-499848?style=flat-square&logo=gunicorn&logoColor=white" alt="Uvicorn" />
    <img src="https://img.shields.io/badge/SQLite-003B57?style=flat-square&logo=sqlite&logoColor=white" alt="SQLite" />
    <img src="https://img.shields.io/badge/SQLAlchemy-D71F00?style=flat-square&logo=sqlalchemy&logoColor=white" alt="SQLAlchemy" />
    <img src="https://img.shields.io/badge/pypdf-FF6F00?style=flat-square&logo=adobeacrobatreader&logoColor=white" alt="pypdf" />
  </p>

  <h4>Frontend &amp; Cross-Platform</h4>
  <p>
    <img src="https://img.shields.io/badge/Flutter_Web-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter Web" />
    <img src="https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white" alt="Dart" />
    <img src="https://img.shields.io/badge/Material_Design_3-757575?style=flat-square&logo=materialdesign&logoColor=white" alt="Material 3" />
    <img src="https://img.shields.io/badge/PWA-5A0FC8?style=flat-square&logo=pwa&logoColor=white" alt="PWA" />
  </p>

  <h4>Cloud Infrastructure &amp; Deployment</h4>
  <p>
    <img src="https://img.shields.io/badge/Render-46E3B7?style=flat-square&logo=render&logoColor=black" alt="Render" />
    <img src="https://img.shields.io/badge/Vercel-000000?style=flat-square&logo=vercel&logoColor=white" alt="Vercel" />
    <img src="https://img.shields.io/badge/Git-F05032?style=flat-square&logo=git&logoColor=white" alt="Git" />
    <img src="https://img.shields.io/badge/GitHub-181717?style=flat-square&logo=github&logoColor=white" alt="GitHub" />
  </p>
</section>

---

### ⏱ 3. 개발 기간 및 로드맵

| 단계 | 구분 | 주요 작업 내용 |
| :---: | :--- | :--- |
| **1단계** | **어휘 데이터 파이프라인 구축** | HSK 5급 어휘 PDF 텍스트 정제, SQLite 스키마 설계 및 2,470단어 DB 적재 |
| **2단계** | **FastAPI 백엔드 개발** | 무작위 4지선다 출제 로직(`GET /api/v1/quiz/random`), CORS 미들웨어 적용 |
| **3단계** | **Flutter Web 프론트엔드 구현** | 단어 카드 렌더링, 4지선다 정/오답 판정, 점수 트래킹 및 오답노트 모달 구현 |
| **4단계** | **모바일 반응형 최적화** | iPhone 등 소형 화면에서 하단 버튼 가림을 방지하기 위한 `SingleChildScrollView` 및 `SafeArea` 적용 |
| **5단계** | **클라우드 배포 및 PWA 전환** | Render(백엔드) 및 Vercel(프론트엔드) 배포, iOS 홈 화면 추가 대응 |



---

### 🚀 4. 핵심 기술 구현 사항

- **PDF 데이터 파싱 및 고속 퀴즈 생성 알고리즘**
  - `pypdf`를 이용해 원본 PDF에서 한자, 병음, 한국어 뜻을 파싱하여 정규화된 DB에 구축
  - 문제 요청 시 정답 단어 1개와 나머지 무작위 오답 3개를 추출하고 셔플하여 프론트엔드에 전달

- **Flutter 기반 단일 코드베이스 크로스 플랫폼 설계**
  - Flutter Web 기술을 적용하여 데스크톱 및 모바일 브라우저 전반에서 일관된 애니메이션과 렌더링 품질 보장
  - 모바일 Safari의 상하단 네비게이션 툴바 환경에 맞춘 반응형 레이아웃 구성

- **실시간 오답 기록 및 순환 복습 큐 시스템**
  - 틀린 단어는 오답 목록에 실시간 적재되며, '오답 복습 모드' 진입 시 오답들로만 구성된 퀴즈 큐 생성
  - 복습 중 정답을 맞힌 단어는 오답 목록에서 자동으로 제거되는 스마트 순환 학습 로직 구현

- **PWA (Progressive Web App) 모바일 단독 실행**
  - `manifest.json` 및 메타 태그 설정을 통해 Safari에서 '홈 화면에 추가' 시 상단 주소창이 제거된 독립형(Standalone) 모바일 앱 환경 지원

- **클라우드 CI/CD 분리 아키텍처**
  - 백엔드는 Render 클라우드 환경에서 Uvicorn 비동기 서버로 실행
  - 프론트엔드는 정적 빌드 산출물(`build/web`)을 Vercel 글로벌 엣지 네트워크를 통해 초고속 CDN 캐싱 서빙

---

### 📱 5. 주요 기능 화면

| 퀴즈 출제 & 정답 피드백 | 오답노트 모달 & 복습 모드 |
| :---: | :---: |
|<img width="1179" height="2556" alt="image" src="https://github.com/user-attachments/assets/d4eca0cd-7b41-4691-a09d-0854c8335f0a" />


---

