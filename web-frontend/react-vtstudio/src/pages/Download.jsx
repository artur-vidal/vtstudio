import dados from '../assets/imgs/dados-rpg.jpg'

function Download() {
    return (
        <>
            <section className="download" id="download">
                <img src={dados} alt="Dados RPG" />
                <div>
                    <h2>
                        AFLORE SUA <br />
                        IMAGINAÇÃO E INSTALE <br />
                        O EDITOR PERFETIO <br />
                        PARA VOCÊ
                    </h2>
                    <p>
                        Instale para seu dispositivo windows <br />
                        no botão abaixo
                    </p>
                    <a href="#" className="Download">Download</a>
                </div>
            </section>
        </>
    )
}

export default Download;