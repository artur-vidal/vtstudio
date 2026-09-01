import { useLocation } from 'react-router-dom'
import dados from '../assets/imgs/dados-rpg.jpg'
import board from '../assets/imgs/board-dados.jpg'

function Download() {
    const location = useLocation();
    const isPaginaDownload = location.pathname === '/download';
    return (
        <>
            <section className="download" id="download">
                <img src={dados} alt="Dados RPG" />
                <div>
                    <h2>
                        AFLORE SUA <br />
                        IMAGINAÇÃO E INSTALE <br />
                        O EDITOR PERFEITO <br />
                        PARA VOCÊ
                    </h2>
                    <p>
                        Instale para seu dispositivo windows <br />
                        no botão abaixo
                    </p>
                    <a href="#" className="Download">Download</a>
                </div>
            </section>

            {isPaginaDownload && (
                <section className='instalacao'>
                    <div className='texto-cima'>
                        <h2>Instalação</h2>
                        <p>
                            Após baixar o arquivo, faça seu login ou registre-se no aplicativo, dentro do app,<br />
                            realize as configurações necessárias
                            
                        </p>
                    </div>
                    <img src={board} alt="Board de dados de rpg" />
                    <div className='texto-baixo'>
                        <p>
                            Abra este link para o tutorial de instalação
                        </p>
                        <a href="#">Tutorial</a>
                    </div>
                </section>
            )}
        </>
    )
}

export default Download;