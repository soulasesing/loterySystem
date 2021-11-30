// SPDX-License-Identifier: MIT
pragma solidity >=0.4.4 <0.7.0;
pragma experimental ABIEncoderV2;
import "./ERC20.sol";

contract lotery {
 
 //Instancia del contrato token 
 
   ERC20Basic private token;
   
   //direcciones iniciales
   address public owner;
   address public contrato;
   
   //Numero de token a crear 
   uint  token_creados = 10000;
   
   //event the compra de token 
   event ComprandoTokens (uint, address);
   
    constructor () public{
        token = new ERC20Basic(token_creados);
        owner = msg.sender;
        contrato = address(this);
    }
   

    modifier Unicamente(address _direccion){
        require(_direccion == owner, "no tienes privilegio para esta funcion");
        _;
    }
 
 //---------------------------------------------TOKEN---------------------------------------------------------------------
 
 //establecer precio del token
 function PrecioTocken(uint _numTokens)internal  pure returns(uint){
     
     return _numTokens * (1 ether);
 }
 
 //Generar Mas tocken para la lotery
 function GenerarToken(uint _numTokens) public Unicamente(msg.sender){
     token.increaseTotalSupply(_numTokens);
     
 }
 
 //funcion para comprar tokens comprar boletos para la loteria
 function ComprarToken(uint _numTokens) public payable {
     //colcular el coste de los tokens
     uint coste = PrecioTocken(_numTokens);
     //se requiere que el valor del pagado sea equivalente al coste 
     require (msg.value >= coste, "fondos insuficientes");
     // diferencia a pagar 
     uint returnValue = msg.value - coste;
     // Transfrecia de de la diferencia 
     msg.sender.transfer(returnValue);
     //obtener el balance de tokens del contrato
     uint Balance = TokensDisponibles();
     //filtro  para evaluar los token disponibles 
     require (_numTokens <= Balance, "no hay la cantidad de token disponibles.");
     //transferencia de token al comprador
     token.transfer(msg.sender, _numTokens);
     emit ComprandoTokens(_numTokens, msg.sender);
     
 }
 
 //balance de token en el contrato
  function TokensDisponibles() public view returns (uint){
    return token.balanceOf(address(this));   
 
 }
 //Obtener el balance de tokens acumulados en el Bote
 function Bote() public view returns (uint) {
     return token.balanceOf(owner);
 }
 //Balance de tokens de una Persona 
 function MisTokens() public view returns(uint){
 return token.balanceOf(msg.sender);
 
 }
 
 ////---------------------------------------------DECLARACIONES LOTERIA---------------------------------------------------------------------
 
 
 //Precio del Boletos 
 uint public PrecioBoleto = 5;
 //Relacion entre la personas que compra y los nros. de los Boletos
 mapping(address => uint [] ) idPersonas_boletos;
 //Relacion necesario para identificar al ganador
 mapping (uint => address) ADN_boleto;
 //numero Aleatorio
 uint randNonce = 0;
 //Boletos Generador 
  uint [] boletos_comprados;
  
  //Eventos 
  event boletosComprados(uint, address); //cuando se compra un boleto
  event boletos_ganador(uint); //Evento del ganador
  event tokens_devueltos(uint, address); //evento para devolver tokens
 
 //funcion para comprar Boletos de LOTERIA---------------------------------------------------------------------
 
 function ComprarBoleto(uint _boletos) public{
     //Precio Total de los boletos a comprar 
     uint precio_total = _boletos * PrecioBoleto;
     //Filtrado de los token a comprar
     require (precio_total <= MisTokens(), " no tienes suficiente token");
     // transferencia de token al owner --> bote/premio
     
     
     /*
         EL ciente paga la atraccion en tokens
        - Fue necesario crear una funcion en ERC20.sol con el nombre transferenciaLoteria
        debido a que en caso de usar el tansfer o transferFrom  que se escogian para la transaccion estaba equivocdas
        ya el msg.sender qeu recibia el metodo de transfer y transferFrom recibia la direccion del contrato y debe ser la direccion de la persona fisica.
        
     */
     token.transferLoteria(msg.sender, owner, precio_total);
     /*
     se toma la marca actual de tiempo now, el msg.sender y un nonce 
     (un numero que solo se uiliza unavez para que no ejecutemos dos veces la misma funcion de hash con los mismos parametros de entradas)
     en incremento
     Luego se utiliza el keccak256 para convertir estas entradas en un has aleatoreo,
     convertir el ese hash a un uint y luego utilizamos %10000 paa tomar los 4 ultimos digitos 
     Dando un valor aleatorio entre 0 - 9999
     */

     for (uint i=0; i < _boletos; i++){
         uint randon = uint(keccak256(abi.encodePacked(now,msg.sender, randNonce))) % 10000;
         randNonce++;
         //Almacenamos los datos del boleto
         idPersonas_boletos[msg.sender].push(randon);
         //nro de boleto comprado lo almacenos en el array 
         boletos_comprados.push(randon);
         //asignacion del ADN del boleto para tener un ganador
         ADN_boleto[randon] = msg.sender;
        //evento compra de boletos 
         emit boletosComprados(randon, msg.sender);
     }

 }
 
 //funciona para visualizar los nro de boletos de una persona 
        function TusBoletes() public view returns(uint [] memory){
        
        return idPersonas_boletos[msg.sender];
    }

    //funcion para generar un ganador y ingresarle token 

    function GenerarGanador() public Unicamente(msg.sender){
    // validar si hay boletos Comprados
    require(boletos_comprados.length > 0, "no hay boletos comprados");
    //Declarar longitud del array
     uint longitud = boletos_comprados.length;
     //1- aleatoreaente elegino 1 numero entre 0 - longitud
     uint posicion_array = uint(uint(keccak256(abi.encodePacked(now))) % longitud);
     //2- seleccion del nro aleatorio mediante la posicion del arrar 
     uint eleccion = boletos_comprados[posicion_array];
     //Emitimos el Evento
     emit boletos_ganador(eleccion);
    //--------enviar el premio al ganador
    address direccionGanador = ADN_boleto[eleccion];
    //enviarles el premio al ganador 
    token.transferLoteria(msg.sender, direccionGanador, Bote());
    }

    // Devolucion de los Tokens
    function DevolverToken(uint _numTokens) public payable{
        // el nro de token a devolver debe ser mayor a 0
        require(_numTokens > 0, "no tienes suficientes token");
        //Usuario/cliente debe tener los token que desea devolver 
        require(_numTokens <= MisTokens(), "no tiene suficientes token para devolver");
        //Devolucion
        //1. el cliente devuelve los token
        //2. la loteria poga los token devueltos 
        token.transferLoteria(msg.sender, address(this), _numTokens);
        msg.sender.transfer(PrecioTocken(_numTokens));
        //emision del evento
        emit tokens_devueltos(_numTokens, msg.sender);

    }
    
}