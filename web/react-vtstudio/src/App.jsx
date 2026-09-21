import { useState } from 'react'
import { useLocation } from 'react-router-dom'
import './assets/css/App.css'
import { Routes, Route} from 'react-router-dom'
import Navbar from './components/Navbar.jsx'
import Footer from './components/Footer.jsx'
import Mensagem from './components/Mensagem.jsx'
import Home from './pages/Home.jsx'
import Download from './pages/Download.jsx'
import Sobre from './pages/Sobre.jsx'
import Vtstudio from './pages/VTStudio.jsx'
import Dado from './assets/imgs/dado.png'

function App() {
    const location = useLocation();
    return (
        <>
            <div className='app-wrapper'>
                <Navbar />
                <Mensagem />
                <div className='dado-fundo'>
                    <img src={Dado} alt="dado de fundo de tela" className='primeiro'/>
                    <img src={Dado} alt="dado de fundo de tela" className='segundo'/>
                    <img src={Dado} alt="dado de fundo de tela" className='terceiro'/>
                </div>
                <main key={location.pathname} className='fade-pagina'>
                    <Routes>
                        <Route path='/' element={<Home />} />
                        <Route path='/download' element={<Download />} />
                        <Route path='/sobre' element={<Sobre />}/> 
                        <Route path='/vtstudio' element={<Vtstudio />}/> 
                    </Routes>
                </main>
                <Footer />
            </div>
        </>
    );
}

export default App