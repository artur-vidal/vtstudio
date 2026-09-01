import { useLocation } from 'react-router-dom'
import livro from '../assets/imgs/rpg-de-mesa.webp'
import jogo from '../assets/imgs/jogo-de-rpg.jpg'

function Vtstudio() {
    const location = useLocation();
    const isPaginaVtstudio = location.pathname === '/vtstudio';

    return (
        <>
            <section className="Vtstudio" id="Vtstudio">
                <h2>VTSTUDIO</h2>
                <p>
                    O VTStudio é um projeto criado para o TCC do grupo <br />
                    Vandata na escola e curso SENAI
                </p>
                <img src={livro} alt="Livro de RPG com dados" />
                <p>
                    O projeto consiste em uma mesa virtual de RPG totalmente <br />
                    em 3D, onde você coloca seus assets, sejam texturas, <br />
                    músicas ou até videos
                </p>
            </section>
            {isPaginaVtstudio && (
                <section className='vtstudio-extra'>
                    <h2>Propósito</h2>
                    <img src={jogo} alt="Jogo de RPG com mapa e dados de fundo" />
                    <p>
                        O aplicativo vem como uma forma simples e intuitiva de se jogar RPG <br />
                        hoje em dia, com funções que você sempre procurou e com fácil manuseio.
                    </p>
                </section>
            )
            }
        </>
    )
}

export default Vtstudio