import stockImage from '../assets/imgs/stockImage-PessoasRPG.jpg'
import Download from './Download'
import Sobre from './Sobre'
import Vtstudio from './VTStudio'

function Home() {
    return (
        <>
            <section className="card" id="home">
                <div className='card-overlay'>
                    <p>
                        Desbrave o mundo mágico de <br/> 
                        suas histórias com uma maior <br /> 
                        imersão e melhor uso da <br /> 
                        imaginação. 
                    </p>
                </div>
                <span className='descubra'>descubra mais</span>
                <img src={stockImage} alt="jogadores de RPG" />
            </section>

            <Download />
            <Vtstudio />
            <Sobre />
        </>
    )
}

export default Home