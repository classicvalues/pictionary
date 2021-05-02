/* eslint-disable camelcase */
import React, { useEffect, useRef } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import CanvasDraw from 'react-canvas-draw';
import { HANDLE_CANVAS_UPDATE } from '../../constants/actionTypes';
import './GameCanvas.scss';

const GameCanvas = () => {
  const canvasRef = useRef(null);
  let innerCanvasRef = useRef(null);
  const dispatch = useDispatch();
  const [canvasData, isAdmin] = useSelector(state => [state.gamePlay.canvasData, state.game.creator_id === state.userInfo.id]);
  if (!isAdmin && canvasData) canvasRef?.current?.loadSaveData(canvasData, true);

  // Trying to get continously tirggering canvas listener
  // useEffect(() => {
  //   innerCanvasRef = document.querySelector('.test canvas');
  //   console.log(innerCanvasRef);
  //   innerCanvasRef.addEventListener('mousemove', (x) => console.log(x));
  //   const ctx1 = temp1.target.getContext('2d');
  //   let imageData = ctx1.getImageData(0, 0, 1000, 1000);
  //   ctx1.putImageData(0, 0, imageData);
  //   // return () => {
  //   //   cleanup
  //   // }
  // }, []);

  return (
    <div className="canvasContainer">
      <CanvasDraw
        ref={canvasRef}
        onChange={e => isAdmin && dispatch({ type: HANDLE_CANVAS_UPDATE, payload: e.getSaveData() })}
        lazyRadius={10}
        brushRadius={3}
        brushColor="#444"
        catenaryColor="#0a0302"
        hideGrid={true}
        canvasWidth="100%"
        canvasHeight="100%"
        disabled={!isAdmin}
        imgSrc={null}
        saveData={null}
        immediateLoading={true}
        hideInterface={false}
        className="test"
      />
    </div>
  );
};

export default GameCanvas;
