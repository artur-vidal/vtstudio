import { useState } from 'react'
import './assets/css/App.css'
import { Routes, Route} from 'react-router-dom'
import Navbar from './components/Navbar.jsx'
import Footer from './components/Footer.jsx'
import Mensagem from './components/Mensagem.jsx'
import Home from './pages/Home.jsx'
import Download from './pages/Download.jsx'
import Sobre from './pages/Sobre.jsx'
import Vtstudio from './pages/VTStudio.jsx'

function App() {
    return (
        <>
            <Navbar />
            <Mensagem />
            <main>
                <Routes>
                    <Route path='/' element={<Home />} />
                    <Route path='/download' element={<Download />} />
                    <Route path='/sobre' element={<Sobre />}/> 
                    <Route path='/vtstudio' element={<Vtstudio />}/> 
                </Routes>
            </main>
            <Footer />
        </>
    );
}

export default App