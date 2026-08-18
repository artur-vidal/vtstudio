import stockImage from '../assets/imgs/stockImage-PessoasRPG.jpg'

function Home() {
    return (
        <>
            <section className="Mensagem" id="home">
                    <h1>VTSTUDIO <br /> O EDITOR PERFEITO <br /> PARA SEUS MAPAS DE RPG</h1>
                    <a href="#" className="Download">Download</a>
            </section>

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
        </>
    )
}

export default Home