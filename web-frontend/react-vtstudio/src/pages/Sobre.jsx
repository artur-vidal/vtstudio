import { useState, useEffect } from 'react'
import profile from '../assets/imgs/profilepic.jpg'


const participantes = [
    {
        nome: "Natan Nunes",
        texto: "Criador do VTStudio juntos dos demais membros, \ndesenvolvendo o front end do projeto",
        imagem: profile
    },

    {
        nome: "Artur Vidal",
        texto: "Criador do VTStudio juntos dos demais membros, \ndesenvolvendo o back end do projeto",
        imagem: profile
    },

    {
        nome: "David Marinho",
        texto: "Criador do VTStudio juntos dos demais membros, \ndesenvolvendo o banco de dados do projeto",
        imagem: profile
    },

    {
        nome: "Augusto dos Santos",
        texto: "Criador do VTStudio juntos dos demais membros, \ndesenvolvendo a documentação do projeto",
        imagem: profile
    }
]

const TEMPO_TROCA = 5000;

function Sobre() {
    const [indiceAtual, setIndiceAtual] = useState(0);
    const [trocando, setTrocando] = useState(false);

    useEffect(() => {
        const intervalo = setInterval(() => {
            setTrocando(true);

            setTimeout(() => {
                setIndiceAtual((prev) => (prev + 1) % participantes.length);
                setTrocando(false);
            }, 1500);

        }, TEMPO_TROCA);

        return () => clearInterval(intervalo);
    }, []);

    const atual = participantes[indiceAtual];

    return (
        <>
            <section className='Sobre'>
                <div className={`Sobre-Texto ${trocando ? 'trocando' : ''}`}>
                    <h2>
                        ENTENDA MAIS SOBRE NÓS <br />
                        {atual.nome}
                    </h2>
                    <p>{atual.texto}</p>
                </div>

                <div className='Sobre-Carrossel'>
                    <img
                        src={atual.imagem}
                        alt={atual.nome}
                        className={trocando ? 'trocando' : ''}
                    />
                    <div className={`Sobre-Indicadores ${trocando ? 'trocando' : ''}`}>
                        {participantes.map((_, i) => (
                            <span
                                key={i}
                                className={i === indiceAtual ? "ativo" : ""}
                                onClick={() => setIndiceAtual(i)}
                            ></span>
                        ))}
                    </div>
                </div>
            </section>
        </>
    )
}

export default Sobre