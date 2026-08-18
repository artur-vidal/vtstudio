import logo from '../assets/imgs/vtstudiologo.png'

function Navbar() {
    return(
        <header>
            <nav>
                <ul>
                    <li><a href="">Download</a></li>
                    <li><a href="">VTStudio</a></li>
                    <li><a href=""><img src={logo} alt=""/></a></li>
                    <li><a href="">GitHub</a></li>
                    <li><a href="">Sobre Nós</a></li>
            </ul>
            </nav>
        </header>
    );
}

export default Navbar;