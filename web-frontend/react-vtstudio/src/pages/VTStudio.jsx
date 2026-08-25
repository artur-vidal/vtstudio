import livro from '../assets/imgs/rpg-de-mesa.webp'

function Vtstudio() {
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
        </>
    )
}

export default Vtstudio