<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    
    <title>VTStudio - Falha</title>

    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css" integrity="sha384-sRIl4kxILFvY47J16cr9ZwB07vP4J8+LH7qKQnuqkuIAvNWLzeN8tE5YBujZqJLB" crossorigin="anonymous">
    <link rel="preload" href="https://i.postimg.cc/rsNRPmjy/Dadinho-Vermelho.png" type="image">

    <style>
        @import url('https://fonts.googleapis.com/css2?family=Outfit:wght@100..900&display=swap');

        html, body {
            height: 100%;
            font-family: 'Outfit', 'Segoe UI', sans-serif !important;
        }

        body {
            background: url('https://i.postimg.cc/W3MPjPgq/Wave-Background-OG.png') no-repeat
                #EEDEB4;
            background-size: cover, 100%;
            image-rendering: crisp-edges;
        }

        main {
            image-rendering: auto;
        }

        .text-card {
            padding: 1rem;

            border: 2px solid #747578;
            border-radius: 8px;

            background-color: #FCFCFF;
        }

        .text-card-bottom {
            padding-top: 0;
            margin-top: -10px;
            border-top: none;
            border-top-left-radius: 0;
            border-top-right-radius: 0;
        }

        .lil-dice-wrapper-happy {
            animation: jumping .75s calc(var(--i) * -500ms) cubic-bezier(0.32, 0, 0.67, 0) infinite alternate both
        }

        .lil-dice-wrapper-sad {
            animation: rolling .75s calc(var(--i) * -500ms) cubic-bezier(0.32, 0, 0.67, 0) infinite alternate both
        }

        .lil-dice-happy {
            animation: waveRotation .25s calc(var(--i) * -75ms) ease-in-out infinite alternate both;
        }

        .lil-dice-sad {
            filter: saturate(0.2) contrast(.8);
        }

        .lil-dice-wobble {
            animation: sadWobble 1.5s calc(var(--i) * 75ms) ease-in-out infinite both;
        }

        @keyframes jumping {
            from { transform: translateY(-8px); }
            to { transform: translateY(24px); }
        }

        @keyframes waveRotation {
            from { rotate: 15deg; }
            to { rotate: 25deg; }
        }

        @keyframes sadWobble {
            0% {
                transform: scale3d(1, 1, 1);
            }

            30% {
                transform: scale3d(1.25, 0.75, 1);
            }

            40% {
                transform: scale3d(0.75, 1.25, 1);
            }

            50% {
                transform: scale3d(1.15, 0.85, 1);
            }

            65% {
                transform: scale3d(0.95, 1.05, 1);
            }

            75% {
                transform: scale3d(1.05, 0.95, 1);
            }

            100% {
                transform: scale3d(1, 1, 1);
            }
        }
    </style>
</head>
<body>
    <main class="h-100 container py-4 d-flex flex-column justify-content-center align-items-center">
        <img src="https://i.postimg.cc/XJWwHw8p/Logo.png" alt="Logo VTStudio" height="120" class="mb-4">

        <h1 class="text-card">Algo deu errado...</h1>
        <p class="text-card text-card-bottom">Volte para o aplicativo e tente novamente.</p>

        <div class="d-flex gap-5 mt-4">
            <div class="lil-dice-wrapper-sad" style="--i: 0;">
                <img src="https://i.postimg.cc/rsNRPmjy/Dadinho-Vermelho.png" class="lil-dice-sad lil-dice-wobble">
            </div>
            <div class="lil-dice-wrapper-sad" style="--i: 1;">
                <img src="https://i.postimg.cc/rsNRPmjy/Dadinho-Vermelho.png" class="lil-dice-sad lil-dice-wobble">
            </div>
            <div class="lil-dice-wrapper-sad" style="--i: 2;">
                <img src="https://i.postimg.cc/rsNRPmjy/Dadinho-Vermelho.png" class="lil-dice-sad lil-dice-wobble">
            </div>
            <div class="lil-dice-wrapper-sad" style="--i: 3;">
                <img src="https://i.postimg.cc/rsNRPmjy/Dadinho-Vermelho.png" class="lil-dice-sad lil-dice-wobble">
            </div>
        </div>
    </main>
</body>
</html>