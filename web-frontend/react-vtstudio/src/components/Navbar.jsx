import logo from '../assets/imgs/vtstudiologo.png'
import { Link } from 'react-router-dom'

function Navbar() {
    return(
        <header>
            <nav>
                <ul>
                    <li><Link to="/download">Download</Link></li>
                    <li><Link to="/vtstudio">VTstudio</Link></li>
                    <li><Link to="/"><img src={logo} alt=""/></Link></li>
                    <li><a href="https://github.com">GitHub</a></li>
                    <li><Link to="/sobre">Sobre Nós</Link></li>
            </ul>
            </nav>
        </header>
    );
}

export default Navbar;