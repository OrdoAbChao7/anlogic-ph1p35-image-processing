"""Base class and registry for Algorithm Lab plugins."""
from abc import ABC, abstractmethod
from typing import Dict, Any, Tuple
import numpy as np


class BaseAlgorithm(ABC):
    """Abstract base class for all Algorithm Lab plugins.
    
    Every plugin must implement both visual_reference and hardware_equivalent
    processing methods, allowing direct comparison of software vs FPGA-fixed-point models.
    """
    
    algorithm_id: str = "base"
    display_name: str = "Base Algorithm"
    category: str = "General"
    description: str = ""
    source_reference: str = ""
    license: str = "MIT"
    
    @abstractmethod
    def get_parameter_specs(self) -> list[dict]:
        """Return parameter specifications for Web UI controls.
        
        Format:
        [
            {
                "id": "threshold",
                "label": "Threshold",
                "type": "int" / "float" / "select",
                "default": 128,
                "min": 0,
                "max": 255,
                "step": 1,
                "options": [...] # for select
            }
        ]
        """
        pass

    @abstractmethod
    def process_visual_reference(self, image_rgb: np.ndarray, params: Dict[str, Any]) -> Tuple[np.ndarray, Dict[str, Any]]:
        """Compute floating-point / unconstrained high quality software reference.
        
        Args:
            image_rgb: HxWx3 uint8 RGB image
            params: Dictionary of parameters matching specs
            
        Returns:
            Tuple of (output_rgb, metrics_dict)
        """
        pass

    @abstractmethod
    def process_hardware_equivalent(self, image_rgb: np.ndarray, params: Dict[str, Any]) -> Tuple[np.ndarray, Dict[str, Any]]:
        """Compute fixed-point, bit-accurate, line-buffer-aligned FPGA equivalent model.
        
        Args:
            image_rgb: HxWx3 uint8 RGB image
            params: Dictionary of parameters matching specs
            
        Returns:
            Tuple of (output_rgb, metrics_dict)
        """
        pass

    def compute_diff_heatmap(self, ref_rgb: np.ndarray, hw_rgb: np.ndarray) -> np.ndarray:
        """Compute amplified absolute difference heatmap between visual ref and hw model."""
        import cv2
        diff = np.abs(ref_rgb.astype(np.int16) - hw_rgb.astype(np.int16))
        diff_gray = np.clip(np.mean(diff, axis=2) * 4.0, 0, 255).astype(np.uint8)
        heatmap = cv2.applyColorMap(diff_gray, cv2.COLORMAP_JET)
        return cv2.cvtColor(heatmap, cv2.COLOR_BGR2RGB)
